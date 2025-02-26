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
declare -A iface_ips
for iface in "${interfaces[@]}"; do
  ip_addr=$(ip -o -4 addr show "$iface" | awk '{print $4}' | cut -d/ -f1)
  iface_ips["$iface"]=$ip_addr
done

if [ ${#interfaces[@]} -gt 1 ]; then
  echo "Plusieurs interfaces détectées :"
  for i in "${!interfaces[@]}"; do
    echo "$((i+1))) ${interfaces[$i]} : ${iface_ips[${interfaces[$i]}]}"
  done
  read -p "Choisissez une interface (1-${#interfaces[@]}) : " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#interfaces[@]} ]; then
    echo "Choix invalide. Arrêt du script."
    exit 1
  fi
  INTERFACE=${interfaces[$((choice-1))]}
else
  INTERFACE=${interfaces[0]}
  echo "Interface unique détectée : $INTERFACE : ${iface_ips[$INTERFACE]}"
fi

# Récupérer l'adresse IP de l'interface sélectionnée
IP=${iface_ips[$INTERFACE]}
echo "Interface sélectionnée : $INTERFACE"
echo "Adresse IP détectée : $IP"

# Création d'un inventaire minimal pour Ansible
cat <<EOF > /etc/ansible/hosts
[local]
$IP ansible_connection=local
EOF

echo "Installation et configuration d'Ansible terminées."
