# Scripts Ansible & Proxmox

## Français

### À propos
Ce dépôt contient :
- **install_ansible.sh** : Installe et configure Ansible sur Debian 12 (détecte automatiquement l'IP et l'interface).
- **manage_ansible.sh** : Menu interactif pour gérer Ansible (afficher l'inventaire, lancer des playbooks, voir les logs).
- **Playbook_Proxmox_Vm.yml** : Déploie rapidement une VM sur Proxmox (avec option snapshot).

Les scripts incluent une gestion avancée des erreurs pour être plus robustes.

### Prérequis
- Debian 12
- Exécution en root
- Outils : apt, ip, awk, curl, tail, etc.
- Pour Proxmox : accès à l’API et installation de `community.general` via  
  `ansible-galaxy collection install community.general`

### Utilisation
1. Rendez les scripts exécutables :
   ```bash
   sudo git clone https://github.com/Vapotank/BLUE-TEAM-SDV
   cd BLUE-TEAM-SDV/ANCSIBLE/
   chmod +x install_ansible.sh manage_ansible.sh
   ./manage_ansible.sh

   ./install_ansible.sh 