#!/usr/bin/env bash
set -eo pipefail  # Removed -u flag to allow associative array iteration

# ======= AWS Credentials =======
AWS_ACCESS_KEY_ID="ASIAU6GDWL3RIW6AQGOR"
AWS_SECRET_ACCESS_KEY="LU/mgiqSf9jojUJ/UmfvAoYIBvJ/uWrraKU3q2+g"
AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEIf//////////wEaCXVzLXdlc3QtMiJGMEQCIHxsAw1yhytJTV0y+ucMiVzeTvzN2LHaisfUudbF5zxTAiB1hYh4oc+3X9h/GGs5s5FzDGpgJx8mhcLoF9kSglw4TyqzAghQEAAaDDMzOTcxMjgyNzEwNiIMPJvY9LAWaXb12dKUKpACba7XdvJBFEDxpVAB5U8+WLVd36mUyTvXz5ZZd2jQGJwItuoyTA0d+kYfw8JqfH+2GxcKZ4RoaAHnSelo9zdIEkBPze9Cah+p++o8Wb3aMcGrfVTpx5/VULks3MlitWwbNqnGSpDnd4NZNmhMMQ16/wLRYHtI2jX77wO8Y6qwwOz9jGPzGmRY2R8QXPwKqmTqlTR1iTL76YZMRwyWBg2IwuvPcRaRKj1uZnpnobSGZ9sw+UdoewnDRhFgBLqc2wfUzFuQN6hEaO5LtIH+8Cx5YYfNeaRBk+kyzWdCP2V+zgZn1AYFIPu2VJ1Kstob9xvJSADzK3tn+Ywh9li6a9itC4fIOgFpaoHeuB1+ZVWieWMwm8yfyAY6ngFRFVMNebtt2aMUbpEtLfvx2U2RAd0swVWXNUTiOzz4Rl8/DW14reGfSDtAW9glJOyXnu2tjFoC8zcUKcIMCDM57AzPQrvSXtufetHPHf7TkSRJbCyzP33IyMFs3nvcM/rgg8t02mAJssz9UBDhXm25F4I9SmsyzELlKd135OB9rcsM8jDqhnpB6MO9K31rD5a79roZeKNAFgUDGoDCqQ=="

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

# 检查必要工具
command -v jq >/dev/null || { echo "[ERR] jq not found (brew install jq)"; exit 1; }

# 读取 Terraform 输出中的 ECR 仓库信息
echo "[INFO] Reading ECR repo URLs from Terraform outputs..."
pushd "$TF_DIR" >/dev/null
terraform init -input=false >/dev/null

if ! terraform output ecr_repository_urls &>/dev/null; then
  echo "[WARN] ECR repositories not found in Terraform state."
  echo "[INFO] Running 'terraform apply' to create ECR repositories first..."
  terraform apply -auto-approve -target=module.ecr
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
SERVICES_DIRS=("PurchaseService" "QueryService" "RabbitCombinedConsumer")
SERVICES_KEYS=("purchase-service" "query-service" "mq-projection-service")

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
terraform apply -auto-approve \
  -var="service_image_tags={
    \"purchase-service\":\"$TAG\",
    \"query-service\":\"$TAG\",
    \"mq-projection-service\":\"$TAG\"
  }"
popd >/dev/null

echo "[OK] Deployment complete. Current tag: $TAG"