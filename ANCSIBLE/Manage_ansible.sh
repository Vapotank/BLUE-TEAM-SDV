#!/bin/bash
set -euo pipefail
trap 'echo "Erreur détectée à la ligne ${LINENO} avec le code de retour $?"' ERR
exec 2>> /var/log/ansible_manage.log

# Vérifier que le script est lancé en tant que root (si nécessaire)
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez lancer ce script en tant que root."
  exit 1
fi

# Chemin vers le fichier de log
LOG_FILE="/var/log/ansible.log"

while true; do
  echo "======================================"
  echo "Menu de gestion d’Ansible"
  echo "1) Afficher l’inventaire (/etc/ansible/hosts)"
  echo "2) Lancer un playbook unique"
  echo "3) Lancer plusieurs playbooks (en séquence)"
  echo "4) Voir les logs (suivi en temps réel)"
  echo "5) Quitter"
  echo "======================================"
  read -p "Choix : " choix

  case $choix in
    1)
      echo "Contenu de l’inventaire :"
      cat /etc/ansible/hosts
      ;;
    2)
      read -p "Chemin complet du playbook : " playbook
      if [ -f "$playbook" ]; then
        ansible-playbook "$playbook" | tee -a "$LOG_FILE"
      else
        echo "Le fichier $playbook n’existe pas."
      fi
      ;;
    3)
      echo "Entrez les chemins complets des playbooks séparés par un espace :"
      read -a playbooks
      for pb in "${playbooks[@]}"; do
        if [ -f "$pb" ]; then
          echo "Exécution de $pb ..."
          ansible-playbook "$pb" | tee -a "$LOG_FILE"
        else
          echo "Le fichier $pb n’existe pas."
        fi
      done
      ;;
    4)
      if [ -f "$LOG_FILE" ]; then
        echo "Suivi des logs dans $LOG_FILE (Ctrl+C pour quitter)..."
        tail -f "$LOG_FILE"
      else
        echo "Fichier log non trouvé."
      fi
      ;;
    5)
      echo "Au revoir."
      exit 0
      ;;
    *)
      echo "Option invalide. Veuillez choisir 1, 2, 3, 4 ou 5."
      ;;
  esac
done
