#!/bin/bash
set -e

# ==============================================================================
# 🚀 Universal Multi-Service & Microservice Deployer
# Usage: ./deploy.sh <service> <namespace: dev|prod> <branch: dev|main>
# ==============================================================================

SERVICE="$1"
NAMESPACE="${2:-dev}"
BRANCH="${3:-dev}"

echo "=================================================="
echo "🚀 Smart Inventory Deployer"
echo "Target Service: $SERVICE"
echo "Namespace:      $NAMESPACE"
echo "Branch:         $BRANCH"
echo "=================================================="

# Ensure namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"

deploy_single_microservice() {
  local SVC_NAME=$1
  local DOCKERFILE=$2
  local IMAGE_TAG="ims-${SVC_NAME}:latest"
  local DEPLOY_NAME="ims-${SVC_NAME}"

  if [ ! -d "/opt/ims/server/.git" ]; then
    mkdir -p /opt/ims && rm -rf /opt/ims/server
    (git clone -b $BRANCH git@github.com:arbhutale/ims-server.git /opt/ims/server || git clone -b $BRANCH https://github.com/arbhutale/ims-server.git /opt/ims/server)
  fi

  echo "🔄 Updating repository on branch $BRANCH..."
  cd /opt/ims/server
  git fetch origin $BRANCH || true
  git checkout $BRANCH || true
  git pull origin $BRANCH || true

  echo "🔨 Building Docker image: $IMAGE_TAG from $DOCKERFILE..."
  docker build -f $DOCKERFILE -t $IMAGE_TAG .
  
  echo "📦 Importing image into K3s containerd..."
  docker save $IMAGE_TAG | k3s ctr images import -

  echo "♻️ Restarting deployment $DEPLOY_NAME in namespace $NAMESPACE..."
  kubectl rollout restart deployment/$DEPLOY_NAME -n $NAMESPACE
  kubectl rollout status deployment/$DEPLOY_NAME -n $NAMESPACE --timeout=60s || true
  echo "✅ $SVC_NAME successfully deployed to $NAMESPACE!"
}

case "$SERVICE" in
  auto|detect|changed)
    echo "🔍 Detecting changed files on branch $BRANCH..."
    if [ ! -d "/opt/ims/server/.git" ]; then
      mkdir -p /opt/ims && rm -rf /opt/ims/server
      (git clone -b $BRANCH git@github.com:arbhutale/ims-server.git /opt/ims/server || git clone -b $BRANCH https://github.com/arbhutale/ims-server.git /opt/ims/server)
    fi
    cd /opt/ims/server
    git fetch origin $BRANCH || true
    PREV_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "HEAD")
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    
    DIFF_OUTPUT=$(git diff --name-only $PREV_COMMIT HEAD 2>/dev/null || echo "services/")
    echo "📋 Changed files:"
    echo "$DIFF_OUTPUT"
    
    DELEGATED=0
    if echo "$DIFF_OUTPUT" | grep -qE "(services/shared/|package.*json|k8s/|gateway/)"; then
      echo "📦 Shared files, core configs, or gateway changed - applying manifests..."
      [ -f k8s/deployments.yaml ] && kubectl apply -f k8s/deployments.yaml -n $NAMESPACE
      if echo "$DIFF_OUTPUT" | grep -q "gateway/"; then
        echo "⚡ Building updated api-gateway image..."
        docker build -t ims-api-gateway:latest ./gateway
        docker save ims-api-gateway:latest | k3s ctr images import -
      fi
      /opt/ims/deploy.sh all $NAMESPACE $BRANCH
      DELEGATED=1
    else
      [ -f k8s/deployments.yaml ] && kubectl apply -f k8s/deployments.yaml -n $NAMESPACE
      if echo "$DIFF_OUTPUT" | grep -q "services/catalog_service/"; then
        echo "⚡ Building only catalog-service..."
        deploy_single_microservice "catalog-service" "services/catalog_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/inventory_service/"; then
        echo "⚡ Building only inventory-service..."
        deploy_single_microservice "inventory-service" "services/inventory_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/sales_service/"; then
        echo "⚡ Building only sales-service..."
        deploy_single_microservice "sales-service" "services/sales_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/payment_service/"; then
        echo "⚡ Building only payment-service..."
        deploy_single_microservice "payment-service" "services/payment_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/logistics_service/"; then
        echo "⚡ Building only logistics-service..."
        deploy_single_microservice "logistics-service" "services/logistics_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/communication_service/"; then
        echo "⚡ Building only communication-service..."
        deploy_single_microservice "communication-service" "services/communication_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "services/audit_service/"; then
        echo "⚡ Building only audit-service..."
        deploy_single_microservice "audit-service" "services/audit_service/Dockerfile"
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -q "gateway/"; then
        echo "⚡ Building only api-gateway..."
        docker build -t ims-api-gateway:latest ./gateway
        docker save ims-api-gateway:latest | k3s ctr images import -
        kubectl rollout restart deployment/ims-api-gateway -n $NAMESPACE
        DELEGATED=1
      fi
      if echo "$DIFF_OUTPUT" | grep -qE "(services/core_service/|index.js|Dockerfile)"; then
        echo "⚡ Building only main-backend..."
        docker build -t ims-main-backend:latest -f Dockerfile .
        docker save ims-main-backend:latest | k3s ctr images import -
        kubectl rollout restart deployment/ims-main-backend -n $NAMESPACE
        DELEGATED=1
      fi
    fi

    if [ "$DELEGATED" -eq 0 ]; then
      echo "ℹ️ No specific microservice changed. Ensuring deployments are up to date."
      /opt/ims/deploy.sh all $NAMESPACE $BRANCH
    fi
    ;;

  catalog-service|catalog)
    deploy_single_microservice "catalog-service" "services/catalog_service/Dockerfile"
    ;;

  inventory-service|inventory)
    deploy_single_microservice "inventory-service" "services/inventory_service/Dockerfile"
    ;;

  sales-service|sales)
    deploy_single_microservice "sales-service" "services/sales_service/Dockerfile"
    ;;

  payment-service|payment)
    deploy_single_microservice "payment-service" "services/payment_service/Dockerfile"
    ;;

  logistics-service|logistics)
    deploy_single_microservice "logistics-service" "services/logistics_service/Dockerfile"
    ;;

  communication-service|communication)
    deploy_single_microservice "communication-service" "services/communication_service/Dockerfile"
    ;;

  audit-service|audit)
    deploy_single_microservice "audit-service" "services/audit_service/Dockerfile"
    ;;

  api-gateway|gateway)
    cd /opt/ims/server
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building Gateway Docker image..."
    docker build -t ims-api-gateway:latest ./gateway
    docker save ims-api-gateway:latest | k3s ctr images import -
    kubectl rollout restart deployment/ims-api-gateway -n $NAMESPACE
    kubectl rollout status deployment/ims-api-gateway -n $NAMESPACE --timeout=60s || true
    echo "✅ API Gateway successfully deployed!"
    ;;

  server|main-backend)
    cd /opt/ims/server
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building Main Backend Docker image..."
    docker build -t ims-main-backend:latest -f Dockerfile .
    docker save ims-main-backend:latest | k3s ctr images import -
    kubectl rollout restart deployment/ims-main-backend -n $NAMESPACE
    kubectl rollout status deployment/ims-main-backend -n $NAMESPACE --timeout=60s || true
    echo "✅ Main Backend successfully deployed!"
    ;;

  admin-web|ims-admin-web)
    echo "🔄 Building & Deploying Admin Web on branch $BRANCH..."
    mkdir -p /opt/ims/one-smart-inc-nextjs
    cd /opt/ims/one-smart-inc-nextjs
    if [ -d ".git" ]; then
      git fetch origin $BRANCH 2>/dev/null || true
      git checkout $BRANCH 2>/dev/null || true
      git pull origin $BRANCH 2>/dev/null || true
    fi
    echo "🔨 Building ims-admin-web Docker image..."
    docker build -t ims-admin-web:latest --build-arg NEXT_PUBLIC_API_URL=https://api.smartseth.com/api .
    docker save ims-admin-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-admin-web -n $NAMESPACE
    kubectl rollout status deployment/ims-admin-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Admin Web successfully deployed to $NAMESPACE!"
    ;;

  superadmin-web|ims-superadmin-web)
    echo "🔄 Building & Deploying Superadmin Web on branch $BRANCH..."
    mkdir -p /opt/ims/superadmin-nextjs
    cd /opt/ims/superadmin-nextjs
    if [ -d ".git" ]; then
      git fetch origin $BRANCH 2>/dev/null || true
      git checkout $BRANCH 2>/dev/null || true
      git pull origin $BRANCH 2>/dev/null || true
    fi
    echo "🔨 Building ims-superadmin-web Docker image..."
    docker build -t ims-superadmin-web:latest --build-arg NEXT_PUBLIC_API_URL=https://api.smartseth.com/api .
    docker save ims-superadmin-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-superadmin-web -n $NAMESPACE
    kubectl rollout status deployment/ims-superadmin-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Superadmin Web successfully deployed to $NAMESPACE!"
    ;;

  storefront-web|ims-storefront-web)
    echo "🔄 Building & Deploying Storefront Web on branch $BRANCH..."
    mkdir -p /opt/ims/storefront-nextjs
    cd /opt/ims/storefront-nextjs
    if [ -d ".git" ]; then
      git fetch origin $BRANCH 2>/dev/null || true
      git checkout $BRANCH 2>/dev/null || true
      git pull origin $BRANCH 2>/dev/null || true
    fi
    echo "🔨 Building ims-storefront-web Docker image..."
    docker build -t ims-storefront-web:latest --build-arg NEXT_PUBLIC_API_URL=https://api.smartseth.com/api .
    docker save ims-storefront-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-storefront-web -n $NAMESPACE
    kubectl rollout status deployment/ims-storefront-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Storefront Web successfully deployed to $NAMESPACE!"
    ;;

  app-generator|ims-app-generator)
    echo "🔄 Updating App Generator on branch $BRANCH..."
    if [ ! -d "/opt/ims/ims-app-generator/.git" ]; then
      mkdir -p /opt/ims && rm -rf /opt/ims/ims-app-generator
      (git clone -b $BRANCH git@github.com:arbhutale/ims-app-generator.git /opt/ims/ims-app-generator || git clone -b $BRANCH https://github.com/arbhutale/ims-app-generator.git /opt/ims/ims-app-generator)
    fi
    cd /opt/ims/ims-app-generator
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building App Generator Backend & Frontend images..."
    cd /opt/ims/ims-app-generator/backend && docker build -t ims-generator-backend:latest .
    docker save ims-generator-backend:latest | k3s ctr images import -
    cd /opt/ims/ims-app-generator/frontend && docker build -t ims-generator-frontend:latest .
    docker save ims-generator-frontend:latest | k3s ctr images import -
    cd /opt/ims/ims-app-generator && [ -f k8s/deployments.yaml ] && kubectl apply -f k8s/deployments.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-generator-backend -n $NAMESPACE
    kubectl rollout restart deployment/ims-generator-frontend -n $NAMESPACE
    echo "✅ App Generator successfully deployed to $NAMESPACE!"
    ;;

  tracer-ui|trace-ui|ci-logs)
    echo "🔄 Updating Tracer UI on branch $BRANCH..."
    if [ ! -d "/opt/ims/ims-ci-logs/.git" ]; then
      mkdir -p /opt/ims && rm -rf /opt/ims/ims-ci-logs
      (git clone -b $BRANCH git@github.com:arbhutale/ims-ci-logs.git /opt/ims/ims-ci-logs || git clone -b $BRANCH https://github.com/arbhutale/ims-ci-logs.git /opt/ims/ims-ci-logs)
    fi
    cd /opt/ims/ims-ci-logs
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    cp scripts/deploy.sh /opt/ims/deploy.sh && chmod +x /opt/ims/deploy.sh
    docker build -t ims-trace-ui:latest .
    docker save ims-trace-ui:latest | k3s ctr images import -
    [ -f k8s/tracer-ui.yaml ] && kubectl apply -f k8s/tracer-ui.yaml -n dev
    kubectl delete pod -n dev -l app=web-log-viewer --force --grace-period=0 || true
    echo "✅ Tracer UI successfully deployed with latest changes!"
    ;;

  all)
    echo "🔄 Reloading all microservices in $NAMESPACE..."
    kubectl rollout restart deployment -n $NAMESPACE \
      ims-api-gateway \
      ims-main-backend \
      ims-catalog-service \
      ims-inventory-service \
      ims-sales-service \
      ims-payment-service \
      ims-logistics-service \
      ims-communication-service \
      ims-audit-service || true
    echo "✅ All microservices restarted in $NAMESPACE!"
    ;;

  *)
    echo "⚠️ Unknown service: $SERVICE"
    ;;
esac

echo "🎉 Deployment completed successfully!"
