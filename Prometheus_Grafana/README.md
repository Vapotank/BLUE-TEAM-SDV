# 🚀 Monitoring avec Prometheus, Grafana, Node Exporter et Windows Exporter

Ce projet met en place un système de supervision basé sur **Prometheus, Grafana, Node Exporter et Windows Exporter**. Un script d'installation automatique est fourni pour simplifier la mise en place sur Debian.

---

## 📌 Prérequis
- **Serveur Debian** pour Prometheus et Grafana
- **Serveur Debian** avec Node Exporter installé
- **Serveur Windows Server** avec Windows Exporter installé
- **Accès root/administrateur** sur les machines

---

## ⚙️ Installation automatique (Debian)

Le script `install_Prometheus_Grafana.sh` installe et configure **Prometheus, Grafana et Node Exporter**.

### **1️⃣ Télécharger et exécuter le script**
```bash
wget https://github.com/ton-repo/install_Prometheus_Grafana.sh -O install.sh
chmod +x install.sh
sudo ./install.sh
```

Ce script :
✔ Installe **Prometheus**, **Grafana**, **Node Exporter** et leurs dépendances.  
✔ Configure Prometheus pour collecter des métriques depuis Node Exporter et Windows Exporter.  
✔ Démarre les services automatiquement.  

Une fois terminé, les accès sont :
- **Prometheus** : `http://<IP_DEBIAN>:9090`
- **Grafana** : `http://<IP_DEBIAN>:3000` *(User: `admin`, Pass: `admin`)*

---

## 🔗 **Installation manuelle**
Si vous préférez une installation manuelle, suivez ces étapes :

### **2️⃣ Installation de Node Exporter sur Debian**
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

### **3️⃣ Installation de Windows Exporter sur Windows Server**
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

### **4️⃣ Ajouter les cibles dans Prometheus**
Éditer `/etc/prometheus/prometheus.yml` :
```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['192.168.1.X:9100']  # IP du serveur Debian

  - job_name: 'windows_exporter'
    static_configs:
      - targets: ['192.168.1.Y:9182']  # IP du serveur Windows
```
Redémarrer Prometheus :
```bash
sudo systemctl restart prometheus
```
Vérifier `http://<IP_PROMETHEUS>:9090/targets`.

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

## ✅ **Conclusion**
Tu as maintenant **un système de monitoring complet** avec **Prometheus, Grafana, Node Exporter et Windows Exporter** 🎉🚀

Si tu as des questions, n’hésite pas à ouvrir une issue sur GitHub !

