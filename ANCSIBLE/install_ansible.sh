#!/bin/bash
set -euo pipefail
trap 'echo "Erreur détectée à la ligne ${LINENO} avec le code de retour $?"' ERR
exec 2>> /var/log/ansible_install.log

# Vérifier que le script est lancé en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez lancer ce script en tant que root."
  exit 1
fi

echo "Mise à jour du système..."
apt update && apt upgrade -y

echo "Installation des paquets nécessaires..."
apt install -y software-properties-common curl iproute2

echo "Installation d'Ansible..."
apt install -y ansible

echo "Détection des interfaces réseau actives :"
# Récupérer la liste des interfaces actives possédant une adresse IPv4
interfaces=($(ip -o -4 addr show | awk '{print $2}' | sort | uniq))
if [ ${#interfaces[@]} -gt 1 ]; then
  echo "Plusieurs interfaces détectées :"
  select iface in "${interfaces[@]}"; do
    if [ -n "$iface" ]; then
      INTERFACE=$iface
      break
    else
      echo "Sélection invalide, veuillez réessayer."
    fi
  done
else
  INTERFACE=${interfaces[0]}
  echo "Interface unique détectée : $INTERFACE"
fi

# Récupérer l'adresse IP associée à l'interface sélectionnée
IP=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d/ -f1)
echo "Interface sélectionnée : $INTERFACE"
echo "Adresse IP détectée : $IP"

# Création d'un inventaire minimal pour Ansible
cat <<EOF > /etc/ansible/hosts
[local]
$IP ansible_connection=local
EOF

echo "Installation et configuration d'Ansible terminées."
