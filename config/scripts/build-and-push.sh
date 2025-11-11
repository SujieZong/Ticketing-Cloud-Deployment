#!/usr/bin/env bash
set -eo pipefail  # Removed -u flag to allow associative array iteration

# ======= AWS Credentials =======
AWS_ACCESS_KEY_ID="ASIAU6GDWL3REGDYNDX4"
AWS_SECRET_ACCESS_KEY="ChSEkowRp1R9EFFEujixpB/R6Yc3jK65wZwSiVPP"
AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEIv//////////wEaCXVzLXdlc3QtMiJHMEUCIQC24xP+IlOE3BVgGzfJjPsTJPIfTz6PIVL8ADGNHRjKIAIgcLkjv6EmQGEr+r+O6M9khwAszHs0vHYcFXb9shq+Gq4qswIIVBAAGgwzMzk3MTI4MjcxMDYiDDwdMpEYz0SB7jRp/iqQAhZAzrvxhf1JyPHBMss299cbr/aJnwBa2G/r1LZYruUutnxfSw8wdoTH1w6PCfIacDBOcq0tT8d1M+sIPJpcup1/1N6oCehbomrIzQvXaHjRO9ZhDZSXBpxyJ9HRsPIPomlTb+L1GeFu9K/OmFgESoG4M08oAhIEjvma5POXAcrCBzrPpQfsauffrcYl6O4n3nxrV28DosGWYRy280HmtK53ZGhPqASVVTaokAI2jalbJ2suBGA19AaNTTB+sJSjcK8RrrwBBVSvIQ8AcoenkuCbtpJCui6WEHZ+6twqK0Ryhn1M5L4iXj5hOc8YbHFERb3BSjJ6+1CsrgMz0U1reE3W8hujff+V0SuqgcG51zUfMO27oMgGOp0BwZmCGqDHEhqCEY+8X6i4vaWjLrReEcJtmWtqc2dTsDYTw9YIjILpJzh2D/kcnFhlLPWI1Ft65+P3lzsePhyd4gLYPLdkqYeHynZMffus09DYlsRSx9W9bPbw9qBnnIT16fk2k6AZJZu99yoIu22cYDtODnAAz9f3irVxc5Jpuy2w7q+9MPUoulhK6Wei8buZg9zuIjEjrn7XQfoCGQ=="

# ======= Other Variables =======

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
TF_DIR="${TF_DIR:-$REPO_ROOT/config/terraform}" 
AWS_REGION="${AWS_REGION:-us-west-2}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG="${TAG:-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"      

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
export AWS_REGION

echo "[INFO] Using hardcoded AWS credentials (Learner Lab)"
aws sts get-caller-identity || { echo "[ERR] Invalid credentials"; exit 1; }

# Check Essential Tools
command -v jq >/dev/null || { echo "[ERR] jq not found (brew install jq)"; exit 1; }

# Get ECR info from Terraform Output
echo "[INFO] Reading ECR repo URLs from Terraform outputs..."
pushd "$TF_DIR" >/dev/null
terraform init -input=false -no-color >/dev/null

if ! terraform output ecr_repository_urls &>/dev/null; then
  echo "[WARN] ECR repositories not found in Terraform state."
  echo "[INFO] Running 'terraform apply' to create ECR repositories first..."
  terraform apply -auto-approve -no-color -target=module.ecr
  echo "[OK] ECR repositories created. Continuing with image build..."
fi

terraform output -json ecr_repository_urls > /tmp/ecr.json
popd >/dev/null

# 登录 ECR
REGISTRY="$(jq -r 'to_entries[0].value | split("/")[0]' /tmp/ecr.json)"
echo "[INFO] Logging into ECR: $REGISTRY"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"


# === Build & Push Images =====================================================
# Service directory name -> Terraform service key mapping
SERVICES_DIRS=("PurchaseService" "QueryService" "MessagePersistenceService")
SERVICES_KEYS=("purchase-service" "query-service" "message-persistence-service")

echo "[INFO] Building & pushing Docker images... TAG=$TAG"

for i in "${!SERVICES_DIRS[@]}"; do
  dir="${SERVICES_DIRS[$i]}"
  key="${SERVICES_KEYS[$i]}"
  repo="$(jq -r --arg k "$key" '.[$k]' /tmp/ecr.json)"

  if [[ -z "$repo" || "$repo" == "null" ]]; then
    echo "[ERR] ECR repo for $key not found"
    exit 1
  fi

  echo "  -> Building $key  =>  $repo:$TAG"
  docker build --platform "$PLATFORM" -t "$repo:$TAG" "$REPO_ROOT/$dir"
  docker push "$repo:$TAG"
done


echo "[INFO] Applying Terraform with new image tags..."
pushd "$TF_DIR" >/dev/null
terraform apply -auto-approve -no-color \
  -var="service_image_tags={
    \"purchase-service\":\"$TAG\",
    \"query-service\":\"$TAG\",
    \"message-persistence-service\":\"$TAG\"
  }"
popd >/dev/null

echo "[OK] Deployment complete. Current tag: $TAG"