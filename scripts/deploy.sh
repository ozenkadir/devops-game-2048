#!/bin/bash
set -e  # Hata olursa scripti durdur

# --- ðŸ§© Variables ---
IMAGE_NAME="tile-2048-game:latest"
CLUSTER_NAME="game-cluster"
KIND_CONFIG="kind-config.yaml"
NAMESPACE="game"
HOSTS_LINE="127.0.0.1 2048.local"
INGRESS_NGINX_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
HOSTS_FILE="/etc/hosts"

# --- 0ï¸âƒ£ Check prerequisites ---
echo "ðŸ”¹ Checking prerequisites..."

for cmd in docker kind kubectl; do
  if ! command -v $cmd &>/dev/null; then
    echo "âŒ $cmd is not installed. Please install it first."
    exit 1
  fi
done

echo "âœ… All prerequisites are met!"

# --- 1ï¸âƒ£ Build Docker image ---
echo "ðŸ”¹ Building Docker image..."
docker build -t "$IMAGE_NAME" .
echo "âœ… Docker image built successfully!"

# --- 2ï¸âƒ£ Create KIND cluster ---
echo "ðŸ”¹ Creating KIND cluster..."
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG" || {
  echo "âŒ Failed to create KIND cluster"
  exit 1
}

# --- 3ï¸âƒ£ Load Docker image into KIND ---
echo "ðŸ”¹ Loading Docker image into KIND..."
kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"

# --- 4ï¸âƒ£ Deploy Nginx Ingress ---
echo "ðŸ”¹ Deploying Nginx Ingress..."
kubectl apply -f "$INGRESS_NGINX_URL"

# --- 5ï¸âƒ£ Wait for Ingress Controller to be ready ---
echo "â³ Waiting for Ingress Controller pods to be ready..."
sleep 10

kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "âœ… Ingress Controller is ready!"

# --- 6ï¸âƒ£ Create namespace & deploy app ---
echo "ðŸ”¹ Creating namespace and deploying application..."
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/deployment.yaml -n "$NAMESPACE"
kubectl apply -f k8s/service.yaml -n "$NAMESPACE"

# --- 7ï¸âƒ£ Wait for app pods ---
echo "â³ Waiting for app pods to be ready..."
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=tile-2048 \
  --timeout=120s

# --- 8ï¸âƒ£ Deploy Ingress ---
echo "ðŸ”¹ Deploying Ingress..."
kubectl apply -f k8s/ingress.yaml -n "$NAMESPACE"

# --- 9ï¸âƒ£ Add domain to /etc/hosts ---
echo "ðŸ”¹ Updating /etc/hosts..."
if ! grep -q "2048.local" "$HOSTS_FILE"; then
  echo "$HOSTS_LINE" | sudo tee -a "$HOSTS_FILE" >/dev/null
  echo "âœ… Added '127.0.0.1 2048.local' to /etc/hosts"
else
  echo "â„¹ï¸ Hosts file already contains entry for 2048.local"
fi

# --- ðŸ”Ÿ Flush DNS cache ---
echo "ðŸ”¹ Flushing DNS cache..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  echo "âœ… macOS DNS cache flushed!"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo systemd-resolve --flush-caches || true
  echo "âœ… Linux DNS cache flushed!"
fi

# --- âœ… Done ---
echo ""
echo "==========================================="
echo "âœ… Deployment completed successfully!"
echo "ðŸŒ Open your browser: http://2048.local"
echo "==========================================="
echo ""
echo "To check status, run:"
echo "kubectl get pods -n game"
echo "kubectl get ingress -n game"
echo "kubectl get svc -n game"