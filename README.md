# ⚡ Smart Inventory Suite - CI/CD & Observability Tracer Hub

This repository contains the **Observability & Request Flow Tracer Hub**, declarative **Kubernetes cluster templates**, and universal **CI/CD deployment orchestration scripts** for the Smart Inventory Management System.

---

## 🌟 Architecture & Multi-Repo Ecosystem

The platform consists of 6 repositories managed independently:

| Repository | Description | Port | Tech Stack |
| :--- | :--- | :--- | :--- |
| **`ims-server`** | 8 Microservices + API Gateway + Redis | `8080` (Gateway), `8081` (Backend) | Node.js, Express, Redis, MongoDB |
| **`ims-admin-web`** | Merchant Admin Web Portal | `3000` | Next.js 14, React, Tailwind CSS |
| **`ims-superadmin-web`** | Platform Superadmin Control Center | `3002` | Next.js 14, Standalone Output |
| **`ims-storefront-web`** | Multi-Tenant E-Commerce Storefront | `3001` | Next.js 14, React |
| **`ims-app-generator`** | Dynamic Mobile App Generator | `8000` (Backend), `3005` (Frontend) | FastAPI, Python 3.10, Next.js |
| **`ims-ci-logs`** | Real-Time Microservice Observability Hub | `8888` | Node.js, Express, K8s Client |

---

## 🔄 Universal Server Migration Guide (Future-Proof)

If you migrate to a new server (Hetzner, AWS, GCP, Oracle Cloud, Bare-Metal):

### Step 1: Bootstrap the new VM (60 Seconds)
SSH into the fresh server and run:
```bash
curl -sSL https://raw.githubusercontent.com/arbhutale/ims-ci-logs/dev/scripts/bootstrap-new-server.sh | bash
```

### Step 2: Update Server IP in GitHub Secrets
Update the secret **`SERVER_HOST`** in your GitHub Organization / Repository secrets to point to the new server IP.

### Step 3: Trigger CI/CD
Push any commit to `dev` or `main`. GitHub Actions will automatically connect to the new server, build all images, apply the declarative Kubernetes manifests, and start all services!

---

## 🔍 Observability Tracer Web Dashboard

Access the real-time request flow tracer and live container logs:
👉 **`http://<SERVER_IP>:8888`**

### Features:
- **Topology Architecture View**: Interactive map of all 15 services with real-time health indicators.
- **Trace by ID**: Enter any Order ID, User ID, Trace ID, or Email to trace how requests traverse microservices.
- **Root Cause Highlighting**: Automatically detects and pulses the exact microservice where exceptions or failures occur.
- **Live Pod Log Streamer**: Live tail and inspect container logs for any pod.
- **Environment Toggle**: Switch between `DEV` and `PROD` clusters with 1 click.
