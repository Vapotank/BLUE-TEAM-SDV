#!/bin/bash

set -e  # Arrêt en cas d'erreur
set -u  # Arrêt en cas de variable non définie
set -o pipefail  # Arrêt en cas d'erreur dans un pipe

# Détection automatique de l'IP de la machine Debian
IP_DEBIAN=$(hostname -I | awk '{print $1}')
PROMETHEUS_VERSION="2.47.2"
NODE_EXPORTER_VERSION="1.6.1"
GRAFANA_VERSION="9.6.3"

# Couleurs pour messages
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

log_file="/var/log/install_prometheus_grafana.log"
exec > >(tee -i "$log_file") 2>&1

echo -e "${GREEN}📢 Détection automatique de l'IP : ${IP_DEBIAN}${NC}"
sleep 2

# === INSTALLATION DES DÉPENDANCES ===
echo -e "${GREEN}📢 Mise à jour du système et installation des dépendances...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl tar apt-transport-https software-properties-common

# === INSTALLATION DE PROMETHEUS ===
if ! systemctl is-active --quiet prometheus; then
    echo -e "${GREEN}📢 Installation de Prometheus...${NC}"
    sudo useradd --no-create-home --shell /bin/false prometheus
    sudo mkdir -p /etc/prometheus /var/lib/prometheus
    sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/{prometheus,promtool} /usr/local/bin/
    sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/{consoles,console_libraries} /etc/prometheus/
    sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/

    echo "[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/prometheus.service

    sudo systemctl daemon-reload
    sudo systemctl enable prometheus
    sudo systemctl start prometheus
else
    echo -e "${GREEN}✅ Prometheus est déjà installé.${NC}"
fi

# === INSTALLATION DE NODE EXPORTER ===
if ! systemctl is-active --quiet node_exporter; then
    echo -e "${GREEN}📢 Installation de Node Exporter...${NC}"
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

    echo "[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/node_exporter.service

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
else
    echo -e "${GREEN}✅ Node Exporter est déjà installé.${NC}"
fi

# === INSTALLATION DE GRAFANA ===
if ! systemctl is-active --quiet grafana-server; then
    echo -e "${GREEN}📢 Installation de Grafana...${NC}"
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" -y
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo apt update
    sudo apt install -y grafana

    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
else
    echo -e "${GREEN}✅ Grafana est déjà installé.${NC}"
fi

# === CONFIGURATION DE PROMETHEUS ===
echo -e "${GREEN}📢 Configuration de Prometheus pour inclure Node Exporter et Windows Exporter...${NC}"

echo "global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'windows_exporter'
    static_configs:
      - targets: ['<IP_WINDOWS>:9182']" | sudo tee /etc/prometheus/prometheus.yml

sudo systemctl restart prometheus

echo -e "${GREEN}✅ Installation et configuration terminées sur ${IP_DEBIAN} !${NC}"
echo -e "🔹 Accédez à Prometheus : http://${IP_DEBIAN}:9090"
echo -e "🔹 Accédez à Grafana : http://${IP_DEBIAN}:3000 (user: admin / pass: admin)"
