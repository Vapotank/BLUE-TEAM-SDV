#!/bin/bash

# Activer le mode strict pour stopper le script en cas d'erreur
set -e

# Fichier log
LOG_FILE="/var/log/honeypot_install.log"

# Fonction de rollback en cas d'erreur critique
rollback() {
    echo "⚠️ Une erreur critique est survenue. Nettoyage en cours..." | tee -a "$LOG_FILE"
    systemctl stop cowrie suricata fail2ban apache2 rsyslog 2>/dev/null || true
    rm -rf /opt/cowrie /etc/fail2ban/jail.local /etc/modsecurity/crs \
           /etc/modsecurity/v3.3.0.tar.gz /etc/rsyslog.d/honeypot.conf 2>/dev/null || true
    iptables -F
    echo "🚨 Rollback terminé. Toutes les modifications ont été annulées." | tee -a "$LOG_FILE"
    exit 1
}

# Vérification et installation des paquets manquants
verify_package() {
    dpkg -s "$1" &> /dev/null || {
        echo "📦 Installation du paquet manquant : $1" | tee -a "$LOG_FILE"
        apt install -y "$1" || rollback
    }
}

# Détection automatique de l'interface réseau
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'eth0|ens|enp' | head -n 1)
if [[ -z "$INTERFACE" ]]; then
    echo "❌ Aucune interface réseau détectée. Vérifiez votre configuration."
    exit 1
fi

# Détection automatique de l'adresse IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🔹 Interface détectée : $INTERFACE"
echo "🔹 IP du serveur honeypot détectée : $SERVER_IP"

# Mise à jour du système
echo "🔹 Mise à jour du système..."
apt update && apt upgrade -y

# Installation des dépendances
DEPS=("git" "python3" "python3-pip" "virtualenv" "libssl-dev" "libffi-dev" "build-essential" \
      "iptables" "ufw" "rsyslog" "fail2ban" "suricata" "libapache2-mod-security2" \
      "apache2-utils" "openssl" "cryptsetup")
for pkg in "${DEPS[@]}"; do
    verify_package "$pkg"
done

# Vérification et création des utilisateurs
echo "🔹 Vérification et création de l'utilisateur suricata..."
if ! id "suricata" &>/dev/null; then
    sudo useradd -r -s /usr/sbin/nologin -d /var/lib/suricata suricata
    sudo groupadd suricata
    sudo usermod -aG suricata suricata
fi

# Configuration de Suricata
echo "🔹 Configuration de Suricata..."
sudo mkdir -p /var/log/suricata
sudo chown -R suricata:suricata /var/log/suricata 2>/dev/null || sudo chown -R root:root /var/log/suricata
sudo chmod -R 750 /var/log/suricata
if grep -q 'eth0' /etc/suricata/suricata.yaml; then
    sed -i "s/eth0/$INTERFACE/g" /etc/suricata/suricata.yaml
fi

# Vérification des règles Suricata
if [[ ! -f /etc/suricata/rules/suricata.rules ]]; then
    echo "🔹 Téléchargement des règles Suricata..."
    sudo suricata-update || rollback
fi

# Vérification de la configuration de Suricata
sudo suricata -T -c /etc/suricata/suricata.yaml || rollback

# Configuration de Fail2Ban
echo "🔹 Configuration de Fail2Ban..."
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cat <<EOL > /etc/fail2ban/jail.local
[sshd]
enabled = true
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 600
EOL
fi
sudo touch /var/log/auth.log
sudo chown syslog:adm /var/log/auth.log 2>/dev/null || sudo chown root:adm /var/log/auth.log

# Installation de Cowrie
echo "🔹 Installation de Cowrie..."
sudo useradd -m -s /bin/bash cowrie || true
sudo su - cowrie -c "git clone https://github.com/cowrie/cowrie.git ~/cowrie && cd ~/cowrie && virtualenv cowrie-env && source cowrie-env/bin/activate && pip install -r requirements.txt && cp cowrie.cfg.dist cowrie.cfg"

# Activation des services
SERVICES=("cowrie" "suricata" "fail2ban" "rsyslog")
for service in "${SERVICES[@]}"; do
    systemctl enable "$service" 2>/dev/null || echo "⚠️ Le service $service n'a pas pu être activé. Vérifiez manuellement."
    systemctl restart "$service" 2>/dev/null || echo "⚠️ Le service $service n'a pas pu redémarrer. Vérifiez manuellement."
    systemctl is-active --quiet "$service" && echo "✅ $service est en cours d'exécution." || echo "❌ $service est en échec."
    echo "🔹 Status de $service : $(systemctl is-active "$service")"
done

# Vérification finale
echo "🔹 Vérification de l'état des services..."
for service in "${SERVICES[@]}"; do
    systemctl status "$service" --no-pager | tail -n 10
    echo "-----------------------"
done

# Récapitulatif
echo "\n🎯 Récapitulatif de l'installation :"
for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service")
    echo "🔹 $service : $STATUS"
done

echo "🚀 Installation et configuration terminées avec succès ! 🎯"
