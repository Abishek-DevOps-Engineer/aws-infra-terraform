# Prometheus, Grafana & Node Exporter

## Step-by-Step Installation and Multi-EC2 Monitoring Setup on Ubuntu

This guide covers installing Prometheus, Node Exporter, and Grafana on Ubuntu EC2 instances, creating systemd services, configuring Prometheus to scrape multiple Node Exporters, connecting Grafana to Prometheus, and validating the setup.

## 1. Monitoring architecture

One monitoring EC2 runs Prometheus and Grafana. Production EC2 instances run Node Exporter. Prometheus scrapes Node Exporter; Grafana queries Prometheus.

```text
Monitoring EC2                 Production EC2s
+-----------------------+       +------------------+
| Prometheus :9090      |------>| Node Exporter    |
| Grafana    :3000      |------>| :9100            |
+-----------------------+       +------------------+
                                Prod-1: ap-south-1a
                                Prod-2: ap-south-1b
```

## 2. Prerequisites

- Ubuntu EC2 instances with network connectivity inside the VPC.
- A dedicated monitoring EC2 for Prometheus and Grafana.
- Node Exporter installed on every production EC2 that should be monitored.
- Production Security Groups allow TCP 9100 from the monitoring EC2 Security Group.
- Grafana TCP 3000 should normally be restricted to your own IP or trusted network.
- Use private EC2 IP addresses for Prometheus-to-Node-Exporter communication.

## 3. Install Prometheus

Create the user and directories:

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus
```

Download and install Prometheus (change the version if needed):

```bash
cd /tmp
PROMETHEUS_VERSION="3.15.0"
wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
tar -xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
cd "prometheus-${PROMETHEUS_VERSION}.linux-amd64"

sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo cp prometheus.yml /etc/prometheus/
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
prometheus --version
```

## 4. Configure Prometheus

Edit `/etc/prometheus/prometheus.yml`. Replace placeholder IP addresses and Availability Zones with your production EC2 details.

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'production-servers'
    static_configs:
      - targets: ['<PROD-1-PRIVATE-IP>:9100']
        labels:
          server: 'prod-1'
          availability_zone: '<PROD-1-AZ>'
      - targets: ['<PROD-2-PRIVATE-IP>:9100']
        labels:
          server: 'prod-2'
          availability_zone: '<PROD-2-AZ>'
      # Add more EC2 instances in the same pattern if required.
```

## 5. Create the Prometheus systemd service

Create `/etc/systemd/system/prometheus.service`:

```bash
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'SERVICE'
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
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus --no-pager
```

Validate the configuration:

```bash
promtool check config /etc/prometheus/prometheus.yml
```

## 6. Install Node Exporter

Run this on **each production EC2** you want to monitor. If the user already exists, the command below avoids trying to create it again.

```bash
id node_exporter >/dev/null 2>&1 || sudo useradd --no-create-home --shell /bin/false node_exporter

cd /tmp
NODE_EXPORTER_VERSION="1.10.2"
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar -xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
cd "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"

sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
node_exporter --version
```

## 7. Create the Node Exporter systemd service

```bash
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'SERVICE'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter --no-pager
```

Test the metrics endpoint:

```bash
curl http://localhost:9100/metrics | head
sudo ss -lntp | grep 9100
```

## 8. Install Grafana

Run these commands on the Ubuntu monitoring EC2:

```bash
# 1. Update packages and install dependencies
sudo apt update
sudo apt install -y wget gpg apt-transport-https software-properties-common

# 2. Create the keyrings directory
sudo mkdir -p /etc/apt/keyrings

# 3. Add the official Grafana GPG key
sudo wget -q -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key

# 4. Set key permissions
sudo chmod 644 /etc/apt/keyrings/grafana.asc

# 5. Add the Grafana repository
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# 6. Update package lists
sudo apt update

# 7. Install Grafana
sudo apt install -y grafana

# 8. Enable and start Grafana
sudo systemctl enable --now grafana-server

# 9. Check service status
sudo systemctl status grafana-server --no-pager
```

Optional checks:

```bash
systemctl list-unit-files | grep grafana
systemctl cat grafana-server
sudo ss -lntp | grep 3000
```

## 9. Access Grafana

Open this URL in your browser:

```text
http://<MONITORING-EC2-PUBLIC-IP>:3000
```

On a fresh installation, the default login is normally `admin` / `admin`. Grafana will normally ask you to change the password after the first login.

## 10. Add Prometheus as a Grafana data source

In Grafana, go to **Connections → Data sources → Add data source → Prometheus**. If Grafana and Prometheus are on the same EC2 instance, set the URL to:

```text
http://localhost:9090
```

Click **Save & test**.

## 11. Security Group rules

| Instance | Port | Source / purpose |
|---|---:|---|
| Monitoring EC2 | 3000 | Your IP / trusted network for Grafana |
| Monitoring EC2 | 9090 | Optional; restrict if public access is not needed |
| Production EC2s | 9100 | Monitoring EC2 Security Group |

**Do not expose Node Exporter port 9100 to `0.0.0.0/0`.** Prefer a Security Group reference from the monitoring EC2.

## 12. Validation checklist

Run the first two commands from the monitoring EC2:

```bash
curl http://<PROD-1-PRIVATE-IP>:9100/metrics
curl http://<PROD-2-PRIVATE-IP>:9100/metrics
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl status prometheus --no-pager
sudo systemctl status node_exporter --no-pager
sudo systemctl status grafana-server --no-pager
sudo ss -lntp | grep 9090
sudo ss -lntp | grep 9100
sudo ss -lntp | grep 3000
```

## 13. Practical example for this setup

One monitoring EC2 contains Prometheus and Grafana, while two production EC2 instances contain Node Exporter. Production Security Groups allow TCP 9100 from the monitoring EC2 Security Group.

- **Monitoring EC2:** private IP `10.0.1.52`; Prometheus `:9090`; Grafana `:3000`
- **Prod-1:** private IP `10.0.1.110`; AZ `ap-south-1a`; Node Exporter `:9100`
- **Prod-2:** private IP `10.0.2.38`; AZ `ap-south-1b`; Node Exporter `:9100`

Prometheus configuration for this example:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'production-servers'
    static_configs:
      - targets: ['10.0.1.110:9100']
        labels:
          server: 'prod-1'
          availability_zone: 'ap-south-1a'
      - targets: ['10.0.2.38:9100']
        labels:
          server: 'prod-2'
          availability_zone: 'ap-south-1b'
```

Connectivity tests from the monitoring EC2:

```bash
curl http://10.0.1.110:9100/metrics
curl http://10.0.2.38:9100/metrics
```

Expected Prometheus targets:

- `localhost:9090` — UP
- `10.0.1.110:9100` — UP
- `10.0.2.38:9100` — UP

Useful PromQL tests:

```promql
up
up{job="production-servers"}
node_memory_MemAvailable_bytes{job="production-servers"}
rate(node_cpu_seconds_total{job="production-servers",mode="idle"}[5m])
```

Grafana data source URL:

```text
http://localhost:9090
```

## 14. Final data flow

```text
User Browser
    | TCP 3000
    v
+------------------------+
| Monitoring EC2         |
| Grafana :3000          |
|    | PromQL            |
|    v                   |
| Prometheus :9090       |
+-----------+------------+
            | scrape TCP 9100
         /              \
        v                v
+---------------+  +---------------+
| Production 1  |  | Production 2  |
| ap-south-1a   |  | ap-south-1b   |
| Node Exporter |  | Node Exporter |
| :9100         |  | :9100         |
+---------------+  +---------------+
```

## 15. Troubleshooting

- **Prometheus service not found:** Check `/etc/systemd/system/prometheus.service`, then run `sudo systemctl daemon-reload`.
- **Grafana service not found:** If installed via APT, check `systemctl list-unit-files | grep grafana` and `systemctl cat grafana-server`.
- **Target DOWN:** From the monitoring EC2, run `curl http://<TARGET-PRIVATE-IP>:9100/metrics` and verify the production Security Group.
- **Prometheus configuration error:** Run `promtool check config /etc/prometheus/prometheus.yml`.
- **No Grafana connection:** Verify Prometheus is running and use `http://localhost:9090` when both services are on the same EC2.
- **Port check:** Use `sudo ss -lntp | grep <PORT>`.
- **Service logs:**

```bash
sudo journalctl -u prometheus -n 50 --no-pager
sudo journalctl -u grafana-server -n 50 --no-pager
sudo journalctl -u node_exporter -n 50 --no-pager
```

**Reference architecture principle:** Node Exporter exposes host metrics; Prometheus scrapes and stores those metrics; Grafana queries Prometheus and visualizes the data.
