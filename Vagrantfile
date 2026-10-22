# -*- mode: ruby -*-
require 'yaml'
require 'fileutils'

RACINE = File.dirname(File.expand_path(__FILE__))

# --- Lecture du fichier .env (non versionné) --------------------------------
def charger_env(chemin)
  return {} unless File.exist?(chemin)
  File.readlines(chemin).each_with_object({}) do |ligne, h|
    ligne = ligne.strip
    next if ligne.empty? || ligne.start_with?("#") || !ligne.include?("=")
    cle, val = ligne.split("=", 2)
    h[cle.strip] = val.strip
  end
end
ENV_FICHIER = charger_env(File.join(RACINE, ".env"))
def cfg(cle, defaut)
  ENV[cle] || ENV_FICHIER[cle] || defaut
end

if %w[up provision reload].include?(ARGV[0]) && !File.exist?(File.join(RACINE, ".env"))
  abort "Fichier .env introuvable : copiez .env.exemple en .env (cp .env.exemple .env)"
end

# --- Paramètres --------------------------------------------------------------
GROUPE = cfg("GROUPE", 1).to_i
NB_APP = cfg("NB_APP", 2).to_i
E1     = cfg("E1_LB2", "0") == "1"
E2     = cfg("E2_OBS", "0") == "1"
abort "GROUPE doit être compris entre 1 et 8" unless (1..8).cover?(GROUPE)
abort "NB_APP doit être compris entre 2 et 9" unless (2..9).cover?(NB_APP)

RESEAU  = "192.168.#{55 + GROUPE}"
BOITE   = "bento/ubuntu-24.04"
VERSION = "202404.26.0"

# --- Source unique de vérité : Vagrantfile ET répartiteur en dérivent --------
NOEUDS = []
NOEUDS << { nom: "bdd1", ip: "#{RESEAU}.31", mem: 768, role: "bdd" }
NOEUDS << { nom: "bdd2", ip: "#{RESEAU}.32", mem: 768, role: "replique" }
(1..NB_APP).each do |i|
  NOEUDS << { nom: "app#{i}", ip: "#{RESEAU}.#{20 + i}", mem: 512, role: "app" }
end
NOEUDS << { nom: "lb1", ip: "#{RESEAU}.11", mem: 512, role: "lb" }
NOEUDS << { nom: "lb2", ip: "#{RESEAU}.12", mem: 512, role: "lb" } if E1
NOEUDS << { nom: "obs", ip: "#{RESEAU}.41", mem: 768, role: "obs" } if E2

FileUtils.mkdir_p(File.join(RACINE, "config"))
File.write(File.join(RACINE, "config", "noeuds.yml"),
           NOEUDS.map { |n| n.transform_keys(&:to_s) }.to_yaml)

ENV_VM = {
  "GROUPE" => GROUPE.to_s, "RESEAU" => RESEAU, "NB_APP" => NB_APP.to_s,
  "ENABLE_E1" => E1 ? "1" : "0", "ENABLE_E2" => E2 ? "1" : "0",
  "DB_NAME" => cfg("DB_NAME", "resultats"),
  "DB_USER" => cfg("DB_USER", "appuser"),
  "DB_PASSWORD" => cfg("DB_PASSWORD", ""),
  "REPL_USER" => cfg("REPL_USER", "replicator"),
  "REPL_PASSWORD" => cfg("REPL_PASSWORD", ""),
  "GRAFANA_ADMIN_PASSWORD" => cfg("GRAFANA_ADMIN_PASSWORD", "admin"),
}

Vagrant.configure("2") do |config|
  config.vm.box = BOITE
  config.vm.box_version = VERSION
  config.vm.box_check_update = false

  NOEUDS.each do |n|
    config.vm.define n[:nom] do |m|
      m.vm.hostname = n[:nom]
      m.vm.network "private_network", ip: n[:ip]
      # R8 : seul lb1 expose un port vers l'hôte
      m.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1" if n[:nom] == "lb1"

      m.vm.provider "virtualbox" do |vb|
        vb.name = "rbf-g#{GROUPE}-#{n[:nom]}"
        vb.memory = n[:mem]
        vb.cpus = 1
        vb.linked_clone = true
      end

      env = ENV_VM.merge("MON_IP" => n[:ip], "MON_NOM" => n[:nom])
      m.vm.provision "shell", path: "scripts/#{n[:role]}.sh", env: env
      # Régénérés à chaque 'vagrant up' pour suivre NB_APP (scripts idempotents)
      m.vm.provision "shell", path: "scripts/lb-config.sh", env: env, run: "always"  if n[:role] == "lb"
      m.vm.provision "shell", path: "scripts/obs-config.sh", env: env, run: "always" if n[:role] == "obs"
    end
  end
end
