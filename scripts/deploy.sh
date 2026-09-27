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

deploy_single_microservice() {
  local SVC_NAME=$1
  local DOCKERFILE=$2
  local IMAGE_TAG="ims-${SVC_NAME}:latest"
  local DEPLOY_NAME="ims-${SVC_NAME}"

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
    echo "🔄 Updating Admin Web on branch $BRANCH..."
    cd /opt/ims/one-smart-inc-nextjs || (mkdir -p /opt/ims && git clone -b $BRANCH https://github.com/arbhutale/ims-admin-web.git /opt/ims/one-smart-inc-nextjs && cd /opt/ims/one-smart-inc-nextjs)
    cd /opt/ims/one-smart-inc-nextjs
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building ims-admin-web Docker image..."
    docker build -t ims-admin-web:latest --build-arg NEXT_PUBLIC_API_URL=http://157.180.82.28:8080/api .
    docker save ims-admin-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-admin-web -n $NAMESPACE
    kubectl rollout status deployment/ims-admin-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Admin Web successfully deployed to $NAMESPACE!"
    ;;

  superadmin-web|ims-superadmin-web)
    echo "🔄 Updating Superadmin Web on branch $BRANCH..."
    cd /opt/ims/superadmin-nextjs || (mkdir -p /opt/ims && git clone -b $BRANCH https://github.com/arbhutale/ims-superadmin-web.git /opt/ims/superadmin-nextjs && cd /opt/ims/superadmin-nextjs)
    cd /opt/ims/superadmin-nextjs
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building ims-superadmin-web Docker image..."
    docker build -t ims-superadmin-web:latest --build-arg NEXT_PUBLIC_API_URL=http://157.180.82.28:8080/api .
    docker save ims-superadmin-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-superadmin-web -n $NAMESPACE
    kubectl rollout status deployment/ims-superadmin-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Superadmin Web successfully deployed to $NAMESPACE!"
    ;;

  storefront-web|ims-storefront-web)
    echo "🔄 Updating Storefront Web on branch $BRANCH..."
    cd /opt/ims/storefront-nextjs || (mkdir -p /opt/ims && git clone -b $BRANCH https://github.com/arbhutale/ims-storefront-web.git /opt/ims/storefront-nextjs && cd /opt/ims/storefront-nextjs)
    cd /opt/ims/storefront-nextjs
    git fetch origin $BRANCH || true
    git checkout $BRANCH || true
    git pull origin $BRANCH || true
    echo "🔨 Building ims-storefront-web Docker image..."
    docker build -t ims-storefront-web:latest --build-arg NEXT_PUBLIC_API_URL=http://157.180.82.28:8080/api .
    docker save ims-storefront-web:latest | k3s ctr images import -
    [ -f k8s/deployment.yaml ] && kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl rollout restart deployment/ims-storefront-web -n $NAMESPACE
    kubectl rollout status deployment/ims-storefront-web -n $NAMESPACE --timeout=90s || true
    echo "✅ Storefront Web successfully deployed to $NAMESPACE!"
    ;;

  app-generator|ims-app-generator)
    echo "🔄 Updating App Generator on branch $BRANCH..."
    cd /opt/ims/ims-app-generator || (mkdir -p /opt/ims && git clone -b $BRANCH https://github.com/arbhutale/ims-app-generator.git /opt/ims/ims-app-generator && cd /opt/ims/ims-app-generator)
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
    echo "🔄 Updating Tracer UI..."
    cd /opt/ims/ims-ci-logs
    docker build -t ims-trace-ui:latest .
    docker save ims-trace-ui:latest | k3s ctr images import -
    kubectl delete pod -n dev -l app=web-log-viewer --force --grace-period=0 || true
    echo "✅ Tracer UI successfully deployed!"
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
