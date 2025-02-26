#!/bin/bash
set -euo pipefail

# Définition des couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Chemin du fichier de log
LOG_FILE="/var/log/ansible_manage.log"
touch "$LOG_FILE" || { echo -e "${RED}Impossible de créer le fichier de log $LOG_FILE${NC}"; exit 1; }

# Fonction de gestion d'erreur personnalisée
error_handler() {
    local exit_code=$?
    local line_no=${BASH_LINENO[0]}
    local cmd="${BASH_COMMAND}"
    echo -e "${RED}ERREUR: La commande '${cmd}' a échoué à la ligne ${line_no} avec le code ${exit_code}.${NC}" >&2
    exit $exit_code
}
trap error_handler ERR

# Fonction pour installer et configurer Ansible
install_ansible() {
    echo -e "${BLUE}Installation et configuration d'Ansible...${NC}"
    
    echo -e "${YELLOW}Mise à jour du système...${NC}"
    apt update && apt upgrade -y || { echo -e "${RED}La mise à jour du système a échoué.${NC}"; return 1; }
    
    echo -e "${YELLOW}Installation des paquets nécessaires...${NC}"
    apt install -y software-properties-common curl iproute2 || { echo -e "${RED}L'installation des paquets nécessaires a échoué.${NC}"; return 1; }
    
    echo -e "${YELLOW}Installation d'Ansible...${NC}"
    apt install -y ansible || { echo -e "${RED}L'installation d'Ansible a échoué.${NC}"; return 1; }
    
    echo -e "${YELLOW}Détection des interfaces réseau actives...${NC}"
    interfaces=($(ip -o -4 addr show | awk '{print $2}' | sort | uniq))
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Aucune interface réseau avec une adresse IPv4 détectée.${NC}"
        return 1
    fi
    
    declare -A iface_ips
    for iface in "${interfaces[@]}"; do
        ip_addr=$(ip -o -4 addr show "$iface" | awk '{print $4}' | cut -d/ -f1)
        iface_ips["$iface"]=$ip_addr
    done
    
    if [ ${#interfaces[@]} -gt 1 ]; then
        echo -e "${YELLOW}Interfaces détectées :${NC}"
        for i in "${!interfaces[@]}"; do
            echo -e "$((i+1))) ${interfaces[$i]} : ${iface_ips[${interfaces[$i]}]}"
        done
        read -p "Choisissez une interface (1-${#interfaces[@]}) : " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#interfaces[@]} ]; then
            echo -e "${RED}Choix invalide. Annulation de l'installation.${NC}"
            return 1
        fi
        INTERFACE=${interfaces[$((choice-1))]}
    else
        INTERFACE=${interfaces[0]}
        echo -e "${YELLOW}Interface unique détectée : $INTERFACE : ${iface_ips[$INTERFACE]}${NC}"
    fi
    
    IP=${iface_ips[$INTERFACE]}
    echo -e "${GREEN}Interface sélectionnée : $INTERFACE, Adresse IP : $IP${NC}"
    
    echo -e "${YELLOW}Création du répertoire /etc/ansible (si inexistant)...${NC}"
    mkdir -p /etc/ansible || { echo -e "${RED}Échec de la création du répertoire /etc/ansible.${NC}"; return 1; }
    
    echo -e "${YELLOW}Création du fichier d'inventaire /etc/ansible/hosts...${NC}"
    cat <<EOF > /etc/ansible/hosts
[local]
$IP ansible_connection=local
EOF

    echo -e "${GREEN}Installation et configuration d'Ansible terminées avec succès.${NC}"
    echo "Installation réussie à $(date)" >> "$LOG_FILE"
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction pour exécuter des tâches de maintenance
maintenance() {
    echo -e "${BLUE}Exécution des tâches de maintenance...${NC}"
    
    echo -e "${YELLOW}Mise à jour du système...${NC}"
    apt update && apt upgrade -y || { echo -e "${RED}La mise à jour du système a échoué.${NC}"; return 1; }
    
    echo -e "${YELLOW}Vérification et réinstallation des paquets nécessaires...${NC}"
    apt install -y software-properties-common curl iproute2 ansible || { echo -e "${RED}La vérification/réinstallation des paquets a échoué.${NC}"; return 1; }
    
    echo -e "${GREEN}Tâches de maintenance terminées avec succès.${NC}"
    echo "Maintenance effectuée à $(date)" >> "$LOG_FILE"
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction pour afficher le statut d'Ansible et l'inventaire
status() {
    echo -e "${BLUE}État actuel d'Ansible et du système :${NC}"
    echo -e "${YELLOW}Version d'Ansible installée :${NC}"
    if command -v ansible &>/dev/null; then
        ansible --version
    else
        echo -e "${RED}Ansible n'est pas installé.${NC}"
    fi
    
    echo -e "${YELLOW}Contenu du fichier d'inventaire (/etc/ansible/hosts) :${NC}"
    if [ -f /etc/ansible/hosts ]; then
        cat /etc/ansible/hosts
    else
        echo -e "${RED}Le fichier /etc/ansible/hosts n'existe pas.${NC}"
    fi
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction pour exécuter un playbook via un chemin complet
run_playbook() {
    echo -e "${BLUE}Exécution d'un playbook Ansible...${NC}"
    read -p "Entrez le chemin complet du playbook : " playbook
    if [ ! -f "$playbook" ]; then
        echo -e "${RED}Le fichier $playbook n'existe pas.${NC}"
        echo -e "\nAppuyez sur Entrée pour revenir au menu..."
        read -r
        return 1
    fi
    ansible-playbook "$playbook" | tee -a "$LOG_FILE"
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction pour rechercher des playbooks dans un répertoire et les exécuter
search_and_run_playbook() {
    echo -e "${BLUE}Recherche de playbooks...${NC}"
    read -p "Entrez le répertoire de recherche (appuyez sur Entrée pour le répertoire courant) : " search_dir
    search_dir=${search_dir:-.}
    if [ ! -d "$search_dir" ]; then
        echo -e "${RED}Le répertoire $search_dir n'existe pas.${NC}"
        echo -e "\nAppuyez sur Entrée pour revenir au menu..."
        read -r
        return 1
    fi
    # Rechercher les fichiers .yml et .yaml
    readarray -t playbooks < <(find "$search_dir" -type f \( -iname "*.yml" -o -iname "*.yaml" \))
    if [ ${#playbooks[@]} -eq 0 ]; then
        echo -e "${RED}Aucun playbook trouvé dans $search_dir.${NC}"
        echo -e "\nAppuyez sur Entrée pour revenir au menu..."
        read -r
        return 1
    fi

    echo -e "${YELLOW}Playbooks trouvés dans $search_dir :${NC}"
    for i in "${!playbooks[@]}"; do
        echo -e "$((i+1))) ${playbooks[$i]}"
    done

    read -p "Choisissez un playbook à exécuter (1-${#playbooks[@]}) : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#playbooks[@]} ]; then
        echo -e "${RED}Choix invalide. Annulation de l'exécution.${NC}"
        echo -e "\nAppuyez sur Entrée pour revenir au menu..."
        read -r
        return 1
    fi
    selected_playbook=${playbooks[$((choice-1))]}
    echo -e "${GREEN}Exécution du playbook : ${selected_playbook}${NC}"
    ansible-playbook "$selected_playbook" | tee -a "$LOG_FILE"
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction pour visualiser les logs
view_logs() {
    echo -e "${BLUE}Affichage des logs (Ctrl+C pour quitter)...${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo -e "${RED}Le fichier de log n'existe pas.${NC}"
    fi
}

# Fonction pour afficher une description détaillée du script
description() {
    echo -e "${BLUE}Description du script:${NC}"
    cat <<EOF
Ce script interactif permet de gérer l'installation, la maintenance et le suivi d'Ansible sur Debian 12.
Fonctionnalités incluses :
  - Installation et configuration d'Ansible, incluant la détection interactive de l'interface réseau et la création de /etc/ansible/hosts.
  - Tâches de maintenance : mise à jour du système et vérification des paquets.
  - Affichage de l'état actuel, incluant la version d'Ansible et le contenu de l'inventaire.
  - Exécution de playbooks en entrant directement leur chemin ou via une recherche interactive dans un répertoire.
  - Visualisation des logs en temps réel.
EOF
    echo -e "\nAppuyez sur Entrée pour revenir au menu..."
    read -r
}

# Fonction principale : Menu interactif
main_menu() {
    while true; do
        echo -e "\n${GREEN}------------------ Menu de Gestion d'Ansible ------------------${NC}"
        echo -e "${YELLOW}1) Installer et configurer Ansible"
        echo -e "2) Exécuter des tâches de maintenance"
        echo -e "3) Afficher l'état actuel"
        echo -e "4) Exécuter un playbook (chemin complet)"
        echo -e "5) Rechercher et exécuter un playbook"
        echo -e "6) Visualiser les logs"
        echo -e "7) Afficher la description"
        echo -e "8) Quitter${NC}"
        read -p "Entrez votre choix [1-8] : " choice
        case "$choice" in
            1) install_ansible ;;
            2) maintenance ;;
            3) status ;;
            4) run_playbook ;;
            5) search_and_run_playbook ;;
            6) view_logs ;;
            7) description ;;
            8) echo -e "${GREEN}Au revoir !${NC}"; exit 0 ;;
            *) echo -e "${RED}Choix invalide, veuillez réessayer.${NC}" ;;
        esac
        clear
    done
}

# Lancement du menu interactif si aucun argument n'est fourni
if [ $# -eq 0 ]; then
    clear
    main_menu
else
    # Possibilité d'appeler directement une fonction via un argument en ligne de commande
    case "$1" in
        install) install_ansible ;;
        maintenance) maintenance ;;
        status) status ;;
        playbook) run_playbook ;;
        search) search_and_run_playbook ;;
        logs) view_logs ;;
        description) description ;;
        help) echo "Usage: $0 [install|maintenance|status|playbook|search|logs|description|help]" ;;
        *) echo -e "${RED}Commande inconnue.${NC}"; echo "Usage: $0 [install|maintenance|status|playbook|search|logs|description|help]"; exit 1 ;;
    esac
fi
