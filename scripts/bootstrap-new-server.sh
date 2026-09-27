#!/bin/bash
set -e

# ==============================================================================
# 🚀 Smart Inventory Suite - Universal Server Bootstrap Script
# Supports: Hetzner, AWS EC2, GCP Compute, Oracle Cloud, DigitalOcean, Bare-Metal
# ==============================================================================

echo "=================================================================="
echo "⚡ Bootstrapping Clean Server for Smart Inventory Kubernetes Stack"
echo "=================================================================="

# 1. Update OS packages and install core dependencies
echo "📦 Installing core system packages (Docker, Git, Curl, JQ, SQLite3)..."
apt-get update
apt-get install -y docker.io git curl jq sqlite3 rsync

# 2. Configure 4GB NVMe Swap if total memory < 8GB
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 7000 ] && [ ! -f /swapfile ]; then
  echo "💾 Creating 4GB NVMe Swap space for memory headroom..."
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 3. Install lightweight K3s Kubernetes engine
if ! command -v k3s &> /dev/null; then
  echo "☸️ Installing K3s Kubernetes engine (Lightweight, zero-overhead)..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -
  mkdir -p /root/.kube
  cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
  chmod 600 /root/.kube/config
fi

# 4. Create standard namespaces
echo "🌐 Creating dev and prod namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

# 5. Create deployment directories
echo "📁 Setting up /opt/ims directory structure..."
mkdir -p /opt/ims

echo "=================================================================="
echo "🎉 Server Bootstrap Completed Successfully!"
echo "You can now deploy with GitHub Actions CI/CD or /opt/ims/deploy.sh"
echo "=================================================================="
