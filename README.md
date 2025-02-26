# 🚀 Monitoring et Déploiement de Honeypot avec Prometheus, Grafana et Windows Exporter

Ce projet comprend deux parties principales :
1. **Monitoring** : Mise en place de Prometheus, Grafana, Node Exporter et Windows Exporter pour surveiller les performances des systèmes Debian et Windows.
2. **Honeypot Deployment** : Déploiement d'un honeypot pour détecter et analyser les tentatives d'attaques sur le réseau.

---

## 📌 Prérequis
- **Serveur Debian** pour Prometheus et Grafana
- **Serveur Debian** avec Node Exporter installé
- **Serveur Windows Server** avec Windows Exporter installé
- **Accès root/administrateur** sur les machines
- **Accès Internet** pour récupérer les paquets

---

## ⚙️ Installation automatique (Debian)

### **1️⃣ Télécharger et exécuter le script de Monitoring**
```bash
sudo git clone https://github.com/Vapotank/BLUE-TEAM-SDV
cd BLUE-TEAM-SDV/Prometheus_Grafana
chmod +x install_Prometheus_Grafana.sh
sudo ./install_Prometheus_Grafana.sh
```

### **2️⃣ Télécharger et exécuter le script de déploiement du Honeypot**
```bash
sudo apt install git-all -y
sudo git clone https://github.com/Vapotank/BLUE-TEAM-SDV
cd BLUE-TEAM-SDV/Honeypot_Deployment/
chmod +x install_hony.sh
sudo ./install_hony.sh
```

---

## 🔗 **Installation manuelle du Monitoring**
Si vous préférez une installation manuelle, suivez ces étapes :

### **3️⃣ Installation de Node Exporter sur Debian**
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-1.9.0.linux-amd64.tar.gz
tar xvf node_exporter-1.9.0.linux-amd64.tar.gz
sudo mv node_exporter-1.9.0.linux-amd64/node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter
```
Créer un service systemd :
```bash
echo "[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/node_exporter.service
```
Démarrer le service :
```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

---

### **4️⃣ Installation de Windows Exporter sur Windows Server**
Dans **PowerShell (en admin)** :
```powershell
choco install prometheus-windows-exporter.install -y
```
Créer le service avec les bons collecteurs :
```powershell
sc.exe create windows_exporter binPath= "C:\Program Files\windows_exporter\windows_exporter.exe --collectors.enabled cpu,cs,logical_disk,net,os,system,memory,service" start= auto
Start-Service windows_exporter
```
Ouvrir le port 9182 dans le pare-feu :
```powershell
New-NetFirewallRule -DisplayName "Windows Exporter" -Direction Inbound -Protocol TCP -LocalPort 9182 -Action Allow
```
Vérifier que l’URL `http://<IP_WINDOWS>:9182/metrics` retourne des métriques.

---

## 📊 **Intégration avec Grafana**
### **Ajouter Prometheus comme source de données**
1. Aller dans **Grafana** (`http://<IP_DEBIAN>:3000`)
2. **Configuration > Data Sources > Add Data Source**
3. Sélectionner **Prometheus**, puis entrer l’URL :
   ```
   http://localhost:9090
   ```
4. **Save & Test** ✅

### **Importer des dashboards Grafana**
1. Aller dans **Manage > Import**
2. Utiliser ces IDs :
   - **Node Exporter (Linux)** : `1860`
   - **Windows Exporter** : `2129`
3. Sélectionner Prometheus comme source et valider ✅

---

## 🛡️ **Déploiement d’un Honeypot sur Debian**
Le honeypot est un leurre qui permet de détecter les tentatives d’intrusion sur un serveur.

### **5️⃣ Installation du Honeypot**
```bash
sudo apt update && sudo apt install cowrie -y
```
Configurer Cowrie :
```bash
sudo cp /etc/cowrie/cowrie.cfg.dist /etc/cowrie/cowrie.cfg
```
Démarrer le service Cowrie :
```bash
sudo systemctl enable cowrie
sudo systemctl start cowrie
```
Vérifier les logs d’attaques :
```bash
sudo tail -f /var/log/cowrie/cowrie.log
```

---

## ✅ **Conclusion**
Ce projet combine **monitoring et détection d’intrusion** avec **Prometheus, Grafana, Node Exporter, Windows Exporter et un Honeypot**. 🎉🚀

Si tu as des questions, n’hésite pas à ouvrir une issue sur GitHub !

