#!/bin/bash

set -e

echo "======================================"
echo " Installing Prometheus + Grafana"
echo "======================================"

# ============================================================
# VARIABLES
# ============================================================

PROMETHEUS_VERSION="3.15.0"

PROMETHEUS_USER="prometheus"


# ============================================================
# 1. UPDATE SYSTEM
# ============================================================

echo "[1/10] Updating packages..."

apt-get update -y


# ============================================================
# 2. INSTALL DEPENDENCIES
# ============================================================

echo "[2/10] Installing dependencies..."

apt-get install -y \
    wget \
    tar \
    curl \
    gpg \
    apt-transport-https \
    software-properties-common


# ============================================================
# 3. CREATE PROMETHEUS USER
# ============================================================

echo "[3/10] Creating Prometheus user..."

if ! id "${PROMETHEUS_USER}" >/dev/null 2>&1; then

    useradd \
        --no-create-home \
        --shell /bin/false \
        ${PROMETHEUS_USER}

else

    echo "Prometheus user already exists."

fi


# ============================================================
# 4. CREATE PROMETHEUS DIRECTORIES
# ============================================================

echo "[4/10] Creating Prometheus directories..."

mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

chown ${PROMETHEUS_USER}:${PROMETHEUS_USER} \
    /etc/prometheus

chown ${PROMETHEUS_USER}:${PROMETHEUS_USER} \
    /var/lib/prometheus


# ============================================================
# 5. DOWNLOAD PROMETHEUS
# ============================================================

echo "[5/10] Downloading Prometheus ${PROMETHEUS_VERSION}..."

cd /tmp

wget -q \
    https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

tar -xzf \
    prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

cd prometheus-${PROMETHEUS_VERSION}.linux-amd64


# ============================================================
# INSTALL PROMETHEUS BINARIES
# ============================================================

echo "Installing Prometheus binaries..."

cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

chmod +x /usr/local/bin/prometheus
chmod +x /usr/local/bin/promtool


# ============================================================
# INSTALL PROMETHEUS CONFIGURATION
# ============================================================

echo "Installing Prometheus configuration..."

cp prometheus.yml /etc/prometheus/

cp -r consoles /etc/prometheus/
cp -r console_libraries /etc/prometheus/


# ============================================================
# SET OWNERSHIP
# ============================================================

chown -R ${PROMETHEUS_USER}:${PROMETHEUS_USER} \
    /etc/prometheus

chown -R ${PROMETHEUS_USER}:${PROMETHEUS_USER} \
    /var/lib/prometheus


# ============================================================
# VERIFY PROMETHEUS
# ============================================================

echo "Prometheus version:"

prometheus --version


# ============================================================
# CREATE PROMETHEUS SYSTEMD SERVICE
# ============================================================

echo "Creating Prometheus systemd service..."

cat > /etc/systemd/system/prometheus.service <<EOF

[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]

User=prometheus
Group=prometheus

Type=simple

ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/

Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF


# ============================================================
# GRAFANA INSTALLATION
# ============================================================

echo "======================================"
echo " Installing Grafana"
echo "======================================"


# ============================================================
# 6. ADD GRAFANA REPOSITORY
# ============================================================

echo "[6/10] Adding Grafana repository..."

mkdir -p /etc/apt/keyrings

wget -q -O /etc/apt/keyrings/grafana.asc \
    https://apt.grafana.com/gpg-full.key

chmod 644 /etc/apt/keyrings/grafana.asc


cat > /etc/apt/sources.list.d/grafana.list <<EOF

deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main

EOF


# ============================================================
# 7. UPDATE APT
# ============================================================

echo "[7/10] Updating package repository..."

apt-get update -y


# ============================================================
# 8. INSTALL GRAFANA
# ============================================================

echo "[8/10] Installing Grafana..."

apt-get install -y grafana


# ============================================================
# VERIFY GRAFANA
# ============================================================

echo "Grafana version:"

grafana-server -v


# ============================================================
# 9. START SERVICES
# ============================================================

echo "[9/10] Starting services..."

systemctl daemon-reload

systemctl enable prometheus
systemctl enable grafana-server

systemctl start prometheus
systemctl start grafana-server


# ============================================================
# 10. VERIFY SERVICES
# ============================================================

echo "[10/10] Checking services..."

systemctl is-active prometheus
systemctl is-active grafana-server


echo ""
echo "======================================"
echo " Installation Completed"
echo "======================================"

echo ""
echo "Prometheus:"
echo "  Port: 9090"
echo "  Config: /etc/prometheus/prometheus.yml"
echo "  Data: /var/lib/prometheus"

echo ""
echo "Grafana:"
echo "  Port: 3000"
echo "  Config: /etc/grafana/grafana.ini"

echo ""
echo "Services:"
echo "  Prometheus: $(systemctl is-active prometheus)"
echo "  Grafana:    $(systemctl is-active grafana-server)"

echo ""
echo "======================================"