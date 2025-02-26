#!/bin/bash
set -euo pipefail

# Fonction de gestion d'erreur personnalisée
error_handler() {
    local exit_code=$?
    local line_no=${BASH_LINENO[0]}
    local cmd="${BASH_COMMAND}"
    echo "ERREUR: La commande '${cmd}' a échoué à la ligne ${line_no} avec le code ${exit_code}" >&2
    exit $exit_code
}

trap error_handler ERR

# Fonction d'affichage de l'aide
usage() {
    cat <<EOF
Usage: $0 <command>

Commandes disponibles :
  install       - Installe et configure Ansible (mise à jour, détection d'interface, création de /etc/ansible/hosts)
  description   - Affiche la description et les fonctionnalités du script.
  maintenance   - Exécute les tâches de maintenance (mise à jour du système et vérification des paquets).
  status        - Affiche l'état actuel d'Ansible et du fichier d'inventaire.
  help          - Affiche ce message d'aide.
EOF
}

# Vérifier qu'un argument a été fourni
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    help)
        usage
        exit 0
        ;;
    description)
        cat <<EOF
Description du script :
Ce script a pour but d'installer et configurer Ansible sur une machine Debian 12.
Il effectue les opérations suivantes :
  - Mise à jour du système et installation des paquets nécessaires.
  - Installation d'Ansible.
  - Détection des interfaces réseau actives avec affichage de leur adresse IP.
  - Sélection interactive de l'interface réseau si plusieurs sont disponibles.
  - Création du répertoire /etc/ansible et génération d'un fichier d'inventaire (/etc/ansible/hosts) avec l'adresse IP choisie.
  - Gestion avancée des erreurs avec messages détaillés pour faciliter le débogage.
EOF
        exit 0
        ;;
    maintenance)
        echo "Exécution des tâches de maintenance..."
        echo "Mise à jour du système..."
        if ! apt update && apt upgrade -y; then
            echo "ERREUR: La mise à jour du système a échoué." >&2
            exit 1
        fi
        echo "Vérification des paquets nécessaires..."
        if ! apt install -y software-properties-common curl iproute2 ansible; then
            echo "ERREUR: L'installation ou la vérification des paquets a échoué." >&2
            exit 1
        fi
        echo "Tâches de maintenance terminées avec succès."
        exit 0
        ;;
    status)
        echo "État actuel :"
        echo "Version d'Ansible installée :"
        ansible --version || echo "ERREUR: Ansible n'est pas installé."
        echo ""
        echo "Contenu du fichier d'inventaire (/etc/ansible/hosts) :"
        if [ -f /etc/ansible/hosts ]; then
            cat /etc/ansible/hosts
        else
            echo "Le fichier /etc/ansible/hosts n'existe pas."
        fi
        exit 0
        ;;
    install)
        echo "Installation et configuration d'Ansible..."
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

        echo "Détection des interfaces réseau actives..."
        # Récupérer la liste des interfaces possédant une adresse IPv4
        interfaces=($(ip -o -4 addr show | awk '{print $2}' | sort | uniq))
        if [ ${#interfaces[@]} -eq 0 ]; then
            echo "ERREUR: Aucune interface réseau avec une adresse IPv4 détectée." >&2
            exit 1
        fi

        declare -A iface_ips
        for iface in "${interfaces[@]}"; do
            ip_addr=$(ip -o -4 addr show "$iface" | awk '{print $4}' | cut -d/ -f1)
            iface_ips["$iface"]=$ip_addr
        done

        if [ ${#interfaces[@]} -gt 1 ]; then
            echo "Interfaces détectées :"
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

        echo "Création du répertoire /etc/ansible (si inexistant)..."
        if ! mkdir -p /etc/ansible; then
            echo "ERREUR: Échec de la création du répertoire /etc/ansible." >&2
            exit 1
        fi

        echo "Création du fichier d'inventaire /etc/ansible/hosts..."
        if ! cat <<EOF > /etc/ansible/hosts
[local]
$IP ansible_connection=local
EOF
        then
            echo "ERREUR: Échec de la création du fichier d'inventaire." >&2
            exit 1
        fi

        echo "Installation et configuration d'Ansible terminées avec succès."
        exit 0
        ;;
    *)
        echo "ERREUR: Commande inconnue '$COMMAND'." >&2
        usage
        exit 1
        ;;
esac
