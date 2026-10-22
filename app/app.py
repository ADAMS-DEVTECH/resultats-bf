#!/usr/bin/env python3
"""Service RESULTATS-BF : sans état, tout l'état vit dans la base."""
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import psycopg2

COLONNES = ("matricule", "nom", "serie", "moyenne", "admis")


def connexion():
    # DB_HOSTS = "ip_bdd1,ip_bdd2". Avec target_session_attrs=read-write, libpq
    # ignore une réplique en lecture seule : bdd2 n'est utilisée qu'après promotion.
    return psycopg2.connect(
        host=os.environ["DB_HOSTS"], dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
        connect_timeout=2, target_session_attrs="read-write")


def interroger(sql, params=()):
    conn = connexion()  # une connexion par requête : aucun état local
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchone()
    finally:
        conn.close()


class Gestionnaire(BaseHTTPRequestHandler):
    def repondre(self, code, corps):
        donnees = json.dumps(corps, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(donnees)))
        self.end_headers()
        self.wfile.write(donnees)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/info":
            return self.repondre(200, {"hote": socket.gethostname()})
        try:
            if url.path == "/sante":
                interroger("SELECT 1")
                return self.repondre(200, {"etat": "ok"})
            if url.path == "/resultat":
                matricule = parse_qs(url.query).get("matricule", [""])[0]
                if not matricule:
                    return self.repondre(400, {"erreur": "matricule manquant"})
                ligne = interroger(
                    "SELECT matricule, nom, serie, moyenne::float, admis "
                    "FROM resultats WHERE matricule = %s", (matricule,))
                if ligne is None:
                    return self.repondre(404, {"erreur": "matricule inconnu"})
                return self.repondre(200, dict(zip(COLONNES, ligne)))
        except Exception:
            return self.repondre(503, {"erreur": "base indisponible"})
        self.repondre(404, {"erreur": "route inconnue"})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 3000), Gestionnaire).serve_forever()
