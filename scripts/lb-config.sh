#!/bin/bash
# Génère haproxy.cfg (et keepalived pour E1) depuis config/noeuds.yml.
# Exécuté à chaque 'vagrant up' : idempotent (recharge seulement si changé).
. /vagrant/scripts/lib.sh

NOUVEAU=/tmp/haproxy.cfg.new
python3 - > "$NOUVEAU" <<'PY'
import yaml
noeuds = yaml.safe_load(open("/vagrant/config/noeuds.yml"))
print("""global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    mode http
    log global
    option dontlognull
    timeout connect 2s
    timeout client 30s
    timeout server 30s
    timeout check 4s
    retries 2
    option redispatch

frontend web
    bind *:80
    default_backend apps

backend apps
    balance roundrobin
    option httpchk GET /sante
    http-check expect status 200
    default-server inter 1s fall 2 rise 2""")
for n in noeuds:
    if n["role"] == "app":
        print("    server {} {}:3000 check".format(n["nom"], n["ip"]))
print("""
listen stats
    bind *:8404
    stats enable
    stats uri /""")
PY

haproxy -c -q -f "$NOUVEAU"
if ! cmp -s "$NOUVEAU" /etc/haproxy/haproxy.cfg; then
  install -m 644 "$NOUVEAU" /etc/haproxy/haproxy.cfg
  echo "haproxy.cfg mis à jour"
fi
systemctl reload-or-restart haproxy
systemctl is-active --quiet haproxy

# --- Extension E1 : keepalived / VRRP ---------------------------------------
if [ "${ENABLE_E1}" = "1" ]; then
  command -v keepalived > /dev/null || { apt_update_une_fois; apt_installer keepalived; }
  if [ "${MON_NOM}" = "lb1" ]; then ETAT=MASTER; PRIO=150; PAIR="${RESEAU}.12"
  else ETAT=BACKUP; PRIO=100; PAIR="${RESEAU}.11"; fi
  IFACE=$(ip -o -4 addr show | awk -v ip="${MON_IP}" '$4 ~ "^"ip"/" {print $2}')
  cat > /etc/keepalived/keepalived.conf <<KA
global_defs {
  enable_script_security
  script_user root
}
vrrp_script chk_haproxy {
  script "/usr/bin/pidof haproxy"
  interval 1
  fall 2
  rise 2
}
vrrp_instance VI_1 {
  state ${ETAT}
  interface ${IFACE}
  virtual_router_id $((50 + GROUPE))
  priority ${PRIO}
  advert_int 1
  unicast_src_ip ${MON_IP}
  unicast_peer {
    ${PAIR}
  }
  virtual_ipaddress {
    ${RESEAU}.5/24
  }
  track_script {
    chk_haproxy
  }
}
KA
  systemctl enable keepalived > /dev/null 2>&1
  systemctl restart keepalived
fi
