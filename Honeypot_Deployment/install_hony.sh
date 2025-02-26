#!/bin/bash
set -e

# Vérification que le système est bien Debian
if [ ! -f /etc/debian_version ]; then
    echo "Ce script est destiné à être utilisé uniquement sur Debian."
    exit 1
fi

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

# Fonction pour vérifier et installer un paquet manquant
verify_package() {
    dpkg -s "$1" &> /dev/null || {
        echo "📦 Installation du paquet manquant : $1" | tee -a "$LOG_FILE"
        apt install -y "$1" || rollback
    }
}

# Détection des interfaces réseau compatibles (ex. eth*, ens*, enp*)
interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth0|ens|enp)'))
if [ ${#interfaces[@]} -eq 0 ]; then
    echo "❌ Aucune interface réseau détectée. Vérifiez votre configuration."
    exit 1
elif [ ${#interfaces[@]} -eq 1 ]; then
    INTERFACE="${interfaces[0]}"
    echo "🔹 Interface détectée automatiquement : $INTERFACE"
else
    echo "🔹 Plusieurs interfaces détectées :"
    for i in "${!interfaces[@]}"; do
       echo "  [$i] ${interfaces[$i]}"
    done
    read -p "Entrez le numéro de l'interface à utiliser (par défaut 0) : " choix
    if [[ -z "$choix" ]]; then
         choix=0
    fi
    if ! [[ "$choix" =~ ^[0-9]+$ ]] || [ "$choix" -ge ${#interfaces[@]} ]; then
         echo "❌ Choix invalide."
         exit 1
    fi
    INTERFACE="${interfaces[$choix]}"
    echo "🔹 Interface sélectionnée : $INTERFACE"
fi

# Détection automatique de l'adresse IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "🔹 IP du serveur honeypot détectée : $SERVER_IP"

# Demande des informations du serveur SIEM
read -p "Entrez l'adresse IP du serveur SIEM (laisser vide pour ignorer) : " SIEM_IP
if [[ -n "$SIEM_IP" ]]; then
    read -p "Entrez le port du serveur SIEM : " SIEM_PORT
    echo "🔹 Serveur SIEM configuré : $SIEM_IP sur le port $SIEM_PORT"
fi

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

# Vérification et création de l'utilisateur suricata
echo "🔹 Vérification et création de l'utilisateur suricata..."
if ! id "suricata" &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -d /var/lib/suricata suricata
fi
# Si le groupe existe déjà, groupadd affichera un avertissement (ceci est normal)
groupadd suricata 2>/dev/null || true
usermod -aG suricata suricata

# Configuration de Suricata
echo "🔹 Configuration de Suricata..."
mkdir -p /var/log/suricata
chown -R suricata:suricata /var/log/suricata 2>/dev/null || chown -R root:root /var/log/suricata
chmod -R 750 /var/log/suricata

# Mise à jour de la configuration de Suricata pour utiliser l'interface sélectionnée
if grep -q 'eth0' /etc/suricata/suricata.yaml; then
    sed -i "s/eth0/$INTERFACE/g" /etc/suricata/suricata.yaml
    echo "🔹 Mise à jour de /etc/suricata/suricata.yaml pour utiliser l'interface $INTERFACE"
fi

# Téléchargement des règles Suricata (si nécessaire)
if [[ ! -f /etc/suricata/rules/suricata.rules ]]; then
    echo "🔹 Téléchargement des règles Suricata..."
    suricata-update || rollback
fi

# Correction du chemin des règles : création d'un lien symbolique si nécessaire
if [[ ! -f /etc/suricata/rules/suricata.rules ]] && [[ -f /var/lib/suricata/rules/suricata.rules ]]; then
    echo "🔹 Création d'un lien symbolique pour les règles Suricata..."
    mkdir -p /etc/suricata/rules
    ln -sf /var/lib/suricata/rules/suricata.rules /etc/suricata/rules/suricata.rules
fi

# Configuration du serveur SIEM dans rsyslog, si renseigné
if [[ -n "$SIEM_IP" && -n "$SIEM_PORT" ]]; then
    echo "🔹 Configuration de rsyslog pour le serveur SIEM..."
    cat <<EOL > /etc/rsyslog.d/honeypot.conf
*.* @@${SIEM_IP}:${SIEM_PORT}
EOL
    systemctl restart rsyslog || rollback
fi

# Vérification de la configuration de Suricata
suricata -T -c /etc/suricata/suricata.yaml || rollback

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
touch /var/log/auth.log
chown syslog:adm /var/log/auth.log 2>/dev/null || chown root:adm /var/log/auth.log

# Installation de Cowrie
echo "🔹 Installation de Cowrie..."
if ! id "cowrie" &>/dev/null; then
    useradd -m -s /bin/bash cowrie
fi
su - cowrie -c "git clone https://github.com/cowrie/cowrie.git ~/cowrie || (cd ~/cowrie && git pull)"
cd /home/cowrie/cowrie
virtualenv cowrie-env
source cowrie-env/bin/activate
pip install -r requirements.txt
# Copie du fichier de configuration par défaut
if [ -f etc/cowrie.cfg.dist ]; then
    cp etc/cowrie.cfg.dist cowrie.cfg
elif [ -f cowrie.cfg.dist ]; then
    cp cowrie.cfg.dist cowrie.cfg
else
    echo "⚠️ Fichier de configuration par défaut Cowrie introuvable, veuillez le copier manuellement."
fi

# Création d'un service systemd pour Cowrie (si le fichier de service existe dans le repo, on le copie, sinon on en crée un basique)
if [ -f etc/systemd/cowrie.service ]; then
    cp etc/systemd/cowrie.service /etc/systemd/system/cowrie.service
else
    cat <<EOL > /etc/systemd/system/cowrie.service
[Unit]
Description=Cowrie SSH Honeypot
After=network.target

[Service]
User=cowrie
Group=cowrie
WorkingDirectory=/home/cowrie/cowrie
ExecStart=/home/cowrie/cowrie/bin/cowrie start
ExecStop=/home/cowrie/cowrie/bin/cowrie stop
Restart=always

[Install]
WantedBy=multi-user.target
EOL
fi
systemctl daemon-reload
systemctl enable cowrie
systemctl start cowrie

# Activation des services
SERVICES=("cowrie" "suricata" "fail2ban" "rsyslog")
for service in "${SERVICES[@]}"; do
    systemctl enable "$service" 2>/dev/null || echo "⚠️ Le service $service n'a pas pu être activé. Vérifiez manuellement."
    systemctl restart "$service" 2>/dev/null || echo "⚠️ Le service $service n'a pas pu redémarrer. Vérifiez manuellement."
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service est en cours d'exécution."
    else
        echo "❌ $service est en échec."
    fi
    echo "🔹 Status de $service : $(systemctl is-active "$service")"
done

# Vérification finale
echo "🔹 Vérification de l'état des services..."
for service in "${SERVICES[@]}"; do
    systemctl status "$service" --no-pager | tail -n 10
    echo "-----------------------"
done

# Récapitulatif
echo -e "\n🎯 Récapitulatif de l'installation :"
for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service")
    echo "🔹 $service : $STATUS"
done

echo "🚀 Installation et configuration terminées avec succès ! 🎯"
