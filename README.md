
# Version Française

# BLUE-TEAM-SDV  
# Guide de Déploiement du Honeypot

## 📌 Introduction  
Ce guide décrit comment déployer un honeypot utilisant Suricata, Fail2Ban, Cowrie et Rsyslog sur un système basé sur Debian. Le script d'installation automatise l'installation, la configuration et la vérification des composants requis.  
**Important :** Pour que tous les services fonctionnent correctement, il est nécessaire de redémarrer les services après l'installation.

## 🚀 Installation

### 1️⃣ Prérequis  
Assurez-vous que votre système est à jour avant de lancer le script :
```bash
sudo apt update && sudo apt upgrade -y
```

### 2️⃣ Cloner le dépôt  
```bash
sudo apt install git-all -y
sudo git clone https://github.com/Vapotank/BLUE-TEAM-SDV
cd BLUE-TEAM-SDV
```

### 3️⃣ Attribuer les permissions d'exécution  
```bash
sudo chmod +x install_hony.sh
```

### 4️⃣ Exécuter le script d'installation  
```bash
sudo ./install_hony.sh
```

### 5️⃣ Redémarrer les services  
Une fois l'installation terminée, redémarrez les services pour qu'ils prennent correctement en compte la configuration :
```bash
sudo systemctl restart cowrie suricata fail2ban rsyslog
```

## 🔍 Vérification

Après installation, vérifiez que tous les services fonctionnent correctement :

#### Vérifier les services actifs  
```bash
systemctl list-units --type=service --state=running | grep -E "cowrie|suricata|fail2ban|rsyslog"
```

#### Vérifier l'état des services  
```bash
sudo systemctl status cowrie suricata fail2ban rsyslog
```

#### S'assurer que les services démarrent au démarrage  
```bash
systemctl is-enabled cowrie suricata fail2ban rsyslog
```

#### Consulter les journaux pour détecter des erreurs  
```bash
sudo journalctl -u suricata -n 20 --no-pager
sudo journalctl -u fail2ban -n 20 --no-pager
sudo journalctl -u rsyslog -n 20 --no-pager
```

#### Tester la configuration de Suricata  
```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

#### Vérifier l'état des règles Fail2Ban  
```bash
sudo fail2ban-client status
```

#### Vérifier l'état d'UFW (si activé)  
```bash
sudo ufw status verbose
```

#### Vérifier les règles IPTables  
```bash
sudo iptables -L -v -n
```

## 🛑 Dépannage

- **Suricata ne démarre pas ?**  
  - Consultez le journal :  
    ```bash
    sudo tail -n 20 /var/log/suricata/suricata.log
    ```
  - Vérifiez l'interface réseau configurée dans le fichier :  
    ```bash
    grep "interface:" /etc/suricata/suricata.yaml
    ```

- **Cowrie ne fonctionne pas ?**  
  - Consultez les journaux :  
    ```bash
    sudo journalctl -u cowrie -n 20 --no-pager
    ```

- **Fail2Ban ne bannit pas d'adresses IP ?**  
  - Vérifiez le statut du jail SSH :  
    ```bash
    sudo fail2ban-client status sshd
    ```

## 🔄 Désinstallation

Pour supprimer complètement le honeypot :
```bash
sudo systemctl stop cowrie suricata fail2ban rsyslog
sudo apt remove --purge suricata fail2ban -y
sudo rm -rf /opt/cowrie /var/log/suricata /etc/fail2ban/jail.local
```

## 🎯 Conclusion

Votre honeypot est désormais déployé et opérationnel ! Surveillez régulièrement les journaux pour détecter toute activité suspecte et mettez à jour les règles périodiquement.  
Pour contribuer ou signaler un problème, veuillez soumettre une pull request ou ouvrir une issue sur [GitHub](https://github.com/Vapotank/BLUE-TEAM-SDV).

---

# English Version

# BLUE-TEAM-SDV  
# Honeypot Deployment Guide

## 📌 Introduction  
This guide explains how to deploy a honeypot using Suricata, Fail2Ban, Cowrie, and Rsyslog on a Debian-based system. The installation script automates the installation, configuration, and verification of required components.  
**Important:** To ensure proper operation, you must restart the services after installation.

## 🚀 Installation

### 1️⃣ Prerequisites  
Make sure your system is up-to-date before running the installation script:
```bash
sudo apt update && sudo apt upgrade -y
```

### 2️⃣ Clone the Repository  
```bash
sudo apt install git-all -y
sudo git clone https://github.com/Vapotank/BLUE-TEAM-SDV
cd BLUE-TEAM-SDV
```

### 3️⃣ Set Execution Permissions  
```bash
sudo chmod +x install_hony.sh
```

### 4️⃣ Run the Installation Script  
```bash
sudo ./install_hony.sh
```

### 5️⃣ Restart the Services  
After installation, restart the services so that the new configuration takes effect:
```bash
sudo systemctl restart cowrie suricata fail2ban rsyslog
```

## 🔍 Verification

After installation, verify that all services are running properly:

#### Check Active Services  
```bash
systemctl list-units --type=service --state=running | grep -E "cowrie|suricata|fail2ban|rsyslog"
```

#### Check Service Status  
```bash
sudo systemctl status cowrie suricata fail2ban rsyslog
```

#### Ensure Services Start at Boot  
```bash
systemctl is-enabled cowrie suricata fail2ban rsyslog
```

#### Check Logs for Errors  
```bash
sudo journalctl -u suricata -n 20 --no-pager
sudo journalctl -u fail2ban -n 20 --no-pager
sudo journalctl -u rsyslog -n 20 --no-pager
```

#### Test Suricata Configuration  
```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

#### Check Fail2Ban Rules  
```bash
sudo fail2ban-client status
```

#### Check UFW Status (if enabled)  
```bash
sudo ufw status verbose
```

#### Check IPTables Rules  
```bash
sudo iptables -L -v -n
```

## 🛑 Troubleshooting

- **Suricata is not starting?**  
  - Check the log:
    ```bash
    sudo tail -n 20 /var/log/suricata/suricata.log
    ```
  - Verify the configured network interface:
    ```bash
    grep "interface:" /etc/suricata/suricata.yaml
    ```

- **Cowrie is not running?**  
  - Check the logs:
    ```bash
    sudo journalctl -u cowrie -n 20 --no-pager
    ```

- **Fail2Ban is not banning IPs?**  
  - Check the SSH jail status:
    ```bash
    sudo fail2ban-client status sshd
    ```

## 🔄 Uninstallation

To completely remove the honeypot:
```bash
sudo systemctl stop cowrie suricata fail2ban rsyslog
sudo apt remove --purge suricata fail2ban -y
sudo rm -rf /opt/cowrie /var/log/suricata /etc/fail2ban/jail.local
```

## 🎯 Conclusion

Your honeypot is now deployed and running! Monitor the logs regularly for suspicious activity and update the rules periodically.  
For contributions or issues, please submit a pull request or open an issue on [GitHub](https://github.com/Vapotank/BLUE-TEAM-SDV).

