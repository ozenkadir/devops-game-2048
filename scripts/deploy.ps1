# 2048 Game Deployment for Windows
$ErrorActionPreference = "Stop"

# --- Variables ---
$IMAGE_NAME = "tile-2048-game:latest"
$CLUSTER_NAME = "game-cluster"
$KIND_CONFIG = "kind-config.yaml"
$NAMESPACE = "game"
$HOSTS_LINE = "127.0.0.1 2048.local"
$INGRESS_NGINX_URL = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"

# --- 1️⃣ Build Docker image ---
Write-Host "Building Docker image..."
docker build -t $IMAGE_NAME .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

# --- 2️⃣ Create KIND cluster ---
Write-Host "Creating KIND cluster..."
kind create cluster --name $CLUSTER_NAME --config $KIND_CONFIG
if ($LASTEXITCODE -ne 0) {
    Write-Error "KIND cluster creation failed."
    exit 1
}

# --- 3️⃣ Load Docker image into KIND ---
Write-Host "Loading Docker image into KIND..."
kind load docker-image $IMAGE_NAME --name $CLUSTER_NAME

# --- 4️⃣ Deploy Nginx Ingress ---
Write-Host "Deploying Nginx Ingress..."
kubectl apply -f $INGRESS_NGINX_URL

# --- 5️⃣ Wait for Ingress Controller to be FULLY ready ---
Write-Host "Waiting for Ingress Controller to be ready (this may take 3-4 minutes)..."

Start-Sleep -Seconds 20

Write-Host "Step 1: Waiting for Ingress Controller pods to be ready..."
kubectl wait --namespace ingress-nginx `
  --for=condition=Ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=300s

Write-Host "Step 2: Waiting for admission webhooks to be ready..."
kubectl wait --namespace ingress-nginx `
  --for=condition=Complete job `
  --selector=app.kubernetes.io/component=admission-webhook `
  --timeout=120s 2>$null

Write-Host "Step 3: Final status check..."
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

Write-Host "✅ Ingress Controller is fully ready!"


# Pod'ların running durumuna gelmesini bekle
Write-Host "Step 2: Waiting for Ingress Controller pods to be running..."
kubectl wait --namespace ingress-nginx `
  --for=condition=Ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=300s

# Admission webhook'larının hazır olması için ek bekleme
Write-Host "Step 3: Waiting for admission webhooks to be ready..."
Start-Sleep -Seconds 45

# Final check - tüm ingress bileşenlerini kontrol et
Write-Host "Step 4: Final status check..."
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

Write-Host "✅ Ingress Controller is fully ready!"

# --- 6️⃣ Create Namespace and deploy Application ---
Write-Host "Creating namespace and deploying application..."
kubectl create ns $NAMESPACE
kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
kubectl apply -f k8s/service.yaml -n $NAMESPACE

# --- 7️⃣ Wait for Application pods to be ready ---
Write-Host "Waiting for application pods to be ready..."
kubectl wait --namespace $NAMESPACE `
  --for=condition=ready pod `
  --selector=app=tile-2048 `
  --timeout=120s

# --- 8️⃣ NOW deploy Ingress ---
Write-Host "Deploying Ingress (now that everything is ready)..."
kubectl apply -f k8s/ingress.yaml -n $NAMESPACE

# --- 9️⃣ Verify Ingress ---
Write-Host "Verifying Ingress..."
Start-Sleep -Seconds 10
kubectl get ingress -n $NAMESPACE

# --- 🔟 Update hosts file ---
Write-Host "Updating hosts file..."
if (-not (Select-String -Path $hostsPath -Pattern "2048.local" -Quiet)) {
    Add-Content -Path $hostsPath -Value $HOSTS_LINE
    Write-Host "Added '127.0.0.1 2048.local' to hosts file."
} else {
    Write-Host "Hosts file already contains entry for 2048.local."
}

# --- 1️⃣1️⃣ Flush DNS cache ---
Write-Host "Flushing DNS cache..."
ipconfig /flushdns | Out-Null

Write-Host ""
Write-Host "==========================================="
Write-Host "✅ Deployment completed successfully!"
Write-Host "🌐 Open your browser: http://2048.local"
Write-Host "==========================================="
Write-Host ""
Write-Host "To check status, run:"
Write-Host "kubectl get pods -n game"
Write-Host "kubectl get ingress -n game"
Write-Host "kubectl get svc -n game"
