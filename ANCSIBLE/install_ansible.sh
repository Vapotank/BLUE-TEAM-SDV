#!/bin/bash
set -euo pipefail

# Fonction de gestion d'erreur pour afficher un message détaillé
error_handler() {
    local exit_code=$?
    local line_no=${BASH_LINENO[0]}
    local cmd="${BASH_COMMAND}"
    echo "ERREUR: La commande '${cmd}' a échoué à la ligne ${line_no} avec le code d'erreur ${exit_code}" >&2
    exit $exit_code
}

trap error_handler ERR

# Vérifier que le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

echo "Mise à jour du système..."
if ! apt update && apt upgrade -y; then
    echo "ERREUR: La mise à jour du système a échoué." >&2
    exit 1
fi

echo "Installation des paquets nécessaires..."
if ! apt install -y software-properties-common curl iproute2; then
    echo "ERREUR: L'installation des paquets nécessaires a échoué." >&2
    exit 1
fi

echo "Installation d'Ansible..."
if ! apt install -y ansible; then
    echo "ERREUR: L'installation d'Ansible a échoué." >&2
    exit 1
fi

echo "Détection des interfaces réseau actives :"
# Récupérer la liste des interfaces possédant une adresse IPv4
interfaces=($(ip -o -4 addr show | awk '{print $2}' | sort | uniq))
if [ ${#interfaces[@]} -eq 0 ]; then
    echo "ERREUR: Aucune interface réseau avec une adresse IPv4 n'a été détectée." >&2
    exit 1
fi

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
        echo "ERREUR: Choix invalide. Arrêt du script." >&2
        exit 1
    fi
    INTERFACE=${interfaces[$((choice-1))]}
else
    INTERFACE=${interfaces[0]}
    echo "Interface unique détectée : $INTERFACE : ${iface_ips[$INTERFACE]}"
fi

IP=${iface_ips[$INTERFACE]}
echo "Interface sélectionnée : $INTERFACE"
echo "Adresse IP détectée : $IP"

echo "Création du répertoire /etc/ansible (si non existant)..."
if ! mkdir -p /etc/ansible; then
    echo "ERREUR: Impossible de créer le répertoire /etc/ansible." >&2
    exit 1
fi

echo "Création du fichier d'inventaire /etc/ansible/hosts..."
if ! cat <<EOF > /etc/ansible/hosts
[local]
$IP ansible_connection=local
EOF
then
    echo "ERREUR: Échec de la création du fichier d'inventaire /etc/ansible/hosts." >&2
    exit 1
fi

echo "Installation et configuration d'Ansible terminées avec succès."
