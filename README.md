# BLUE-TEAM-SDV
 # Honeypot Deployment Guide

## 📌 Introduction
This guide explains how to deploy a honeypot using Suricata, Fail2Ban, Cowrie, and Rsyslog on a Debian-based system. The script automates the installation, configuration, and verification of required components.

## 🚀 Installation

### 1️⃣ Prerequisites
Ensure your system is up-to-date before running the installation script:
```bash
sudo apt update && sudo apt upgrade -y
```

### 2️⃣ Clone the repository
```bash
wget https://github.com/Vapotank/BLUE-TEAM-SDV/blob/main/install_hony.sh
cd honeypot-deploy
```

### 3️⃣ Set execution permissions
```bash
sudo chmod +x install_hony.sh
```

### 4️⃣ Run the installation script
```bash
sudo ./install_hony.sh
```

## 🛠️ Components Installed
- **Suricata**: Intrusion Detection/Prevention System (IDS/IPS)
- **Fail2Ban**: Protects against brute-force attacks
- **Cowrie**: SSH honeypot for detecting malicious activities
- **Rsyslog**: Log aggregation for security monitoring

## 🔍 Verification After Installation

After installation, verify that all services are running properly.

### ✅ Check Active Services
```bash
systemctl list-units --type=service --state=running | grep -E "cowrie|suricata|fail2ban|rsyslog"
```

### ✅ Check Service Status
```bash
sudo systemctl status cowrie suricata fail2ban rsyslog
```

### ✅ Ensure Services Start at Boot
```bash
systemctl is-enabled cowrie suricata fail2ban rsyslog
```

### ✅ Check Logs for Errors
```bash
sudo journalctl -u suricata -n 20 --no-pager
sudo journalctl -u fail2ban -n 20 --no-pager
sudo journalctl -u rsyslog -n 20 --no-pager
```

### ✅ Test Suricata Configuration
```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

### ✅ Check Fail2Ban Rules
```bash
sudo fail2ban-client status
```

### ✅ Check Firewall Rules (UFW)
```bash
sudo ufw status verbose
```

### ✅ Check IPTables Rules
```bash
sudo iptables -L -v -n
```

## 🛑 Troubleshooting

If Suricata fails to start, check:
```bash
cat /var/log/suricata/suricata.log | tail -n 20
```

Ensure the correct network interface is set in Suricata's config:
```bash
grep "interface:" /etc/suricata/suricata.yaml
```

If Cowrie is not running:
```bash
sudo journalctl -u cowrie -n 20 --no-pager
```

If Fail2Ban is not banning IPs:
```bash
sudo fail2ban-client status sshd
```

## 🔄 Uninstallation
To remove the honeypot completely:
```bash
sudo systemctl stop cowrie suricata fail2ban rsyslog
sudo apt remove --purge suricata fail2ban -y
sudo rm -rf /opt/cowrie /var/log/suricata /etc/fail2ban/jail.local
```

## 🎯 Conclusion
Your honeypot is now set up and running! Keep monitoring logs for suspicious activity and update the rules regularly.

For contributions or issues, submit a pull request or report an issue on [GitHub](https://github.com/your-repo/honeypot-deploy).


  