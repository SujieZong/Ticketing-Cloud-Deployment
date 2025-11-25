# Testing CI/CD on Sujie-CI/CD Branch

## 🧪 Test Environment Setup

**Branch Structure:**
- `Sujie-CI/CD` = Production (default branch)
- `staging` = Staging environment
- `feature/*` = Feature branches

## 📋 Prerequisites Checklist

```bash
# 1. Check you're on the right branch
git branch --show-current
# Should show: Sujie-CI/CD

# 2. Verify GitHub Secrets are set
# Go to: Settings → Secrets and variables → Actions
# Check: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN

# 3. Create S3 backend (one-time)
cd config/scripts
./setup-s3-backend.sh

# 4. Push the updated workflow
git add .github/workflows/deploy.yml
git commit -m "Update workflow for testing on Sujie-CI/CD"
git push origin Sujie-CI/CD
```

## 🎯 Test Scenario 1: Automated Testing (PR)

**Goal:** Test that tests run automatically on Pull Requests

```bash
# 1. Create a feature branch
git checkout -b feature/test-pr
git push origin feature/test-pr

# 2. Make a small change
echo "// Test change" >> PurchaseService/src/main/java/com/example/ticketing/TicketingApplication.java

# 3. Commit and push
git add .
git commit -m "test: Add comment for CI/CD test"
git push origin feature/test-pr

# 4. Create PR on GitHub
# Go to: https://github.com/YOUR_REPO/compare/Sujie-CI/CD...feature/test-pr
# Click "Create Pull Request"

# ✅ Expected: Tests run automatically
# ✅ Check: Actions tab shows "Run Tests" job
```

**Verification:**
```bash
# Check workflow status
gh run list --branch feature/test-pr

# View logs
gh run view --log
```

---

## 🎯 Test Scenario 2: Auto-Deploy to Staging

**Goal:** Test automatic deployment when pushing to staging

```bash
# 1. Switch to staging branch
git checkout staging

# 2. Make a code change
vim PurchaseService/src/main/resources/application.yml
# Change something minor, like a log level

# 3. Commit and push
git add .
git commit -m "test: Update staging config"
git push origin staging

# 🤖 AUTOMATIC DEPLOYMENT SHOULD START
```

**What to Watch:**
1. GitHub Actions → Watch workflow run
2. Jobs should run in order:
   - ✅ test
   - ✅ build
   - ❌ terraform (skipped)
   - ✅ deploy-services

**Verification:**
```bash
# Check ECS deployment
aws ecs describe-services \
  --cluster purchase-service-cluster \
  --services purchase-service \
  --region us-west-2 \
  --query 'services[0].deployments'

# Check ECR images
aws ecr describe-images \
  --repository-name purchase-service \
  --region us-west-2 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1]'
```

---

## 🎯 Test Scenario 3: Auto-Deploy to Production

**Goal:** Test production deployment

```bash
# 1. Switch to production branch
git checkout Sujie-CI/CD

# 2. Merge staging (simulating promotion)
git merge staging

# 3. Push to production
git push origin Sujie-CI/CD

# 🤖 PRODUCTION DEPLOYMENT SHOULD START
```

**Expected Flow:**
```
Push to Sujie-CI/CD
    ↓
✅ Run tests
    ↓
✅ Build services
    ↓
✅ Build Docker images (tagged: production)
    ↓
✅ Push to ECR
    ↓
✅ Update ECS services
```

---

## 🎯 Test Scenario 4: Manual Services-Only Deployment

**Goal:** Test manual service update without infrastructure changes

```bash
# 1. Make a code change on Sujie-CI/CD
git checkout Sujie-CI/CD
vim QueryService/src/main/java/com/example/ticketing/query/controller/HealthController.java
# Add a comment or minor change

# 2. Commit and push
git add .
git commit -m "test: Minor code change"
git push origin Sujie-CI/CD

# 3. Manual deployment
# Go to GitHub Actions
# Click "Deploy Ticketing System"
# Click "Run workflow"
# Select branch: Sujie-CI/CD
# Select action: services-only
# Click "Run workflow"
```

**Expected:**
- ✅ build job runs
- ❌ terraform job skipped
- ✅ deploy-services job runs

---

## 🎯 Test Scenario 5: Manual Infrastructure Deployment

**Goal:** Test infrastructure changes

```bash
# 1. Make Terraform change
vim config/terraform/variables-rds.tf
# Change a variable

# 2. Commit and push
git add .
git commit -m "test: Update RDS config"
git push origin Sujie-CI/CD

# 3. Manual deployment
# GitHub Actions → Run workflow
# Select: infrastructure-only
```

**Expected:**
- ❌ build job skipped
- ✅ terraform job runs
- ❌ deploy-services skipped

---

## 🔍 Verification Commands

### Check Workflow Status
```bash
# List all runs
gh run list

# Watch current run
gh run watch

# View specific run
gh run view <run-id> --log
```

### Check S3 State
```bash
# Verify state exists
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls s3://ticketing-terraform-state-${ACCOUNT}/ticketing/

# Download state
aws s3 cp s3://ticketing-terraform-state-${ACCOUNT}/ticketing/terraform.tfstate ./
cat terraform.tfstate | jq '.version'
```

### Check Deployed Services
```bash
# ECS services
aws ecs list-services --cluster purchase-service-cluster --region us-west-2

# Get ALB DNS
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?LoadBalancerName==`ticketing-alb`].DNSName' \
  --output text

# Test endpoint
ALB_DNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[0].DNSName' --output text)
curl http://${ALB_DNS}/api/health
```

### Check Docker Images
```bash
# List images with tags
aws ecr describe-images \
  --repository-name purchase-service \
  --region us-west-2 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-3:].[imageTags, imagePushedAt]' \
  --output table
```

---

## 🚨 Troubleshooting

### Problem: Workflow doesn't trigger

**Check:**
```bash
# Verify branch name
git branch --show-current

# Check if workflow file is in the right place
ls -la .github/workflows/deploy.yml

# Verify file is committed
git log -1 --name-only
```

**Fix:**
```bash
git add .github/workflows/deploy.yml
git commit -m "Add workflow file"
git push origin Sujie-CI/CD
```

---

### Problem: Tests fail

**Check logs:**
```bash
gh run view --log | grep -A 20 "Run Tests"
```

**Fix:**
```bash
# Run tests locally
cd PurchaseService
mvn test

# Fix issues and push again
```

---

### Problem: Can't find ECS cluster

**Check:**
```bash
aws ecs list-clusters --region us-west-2
```

**Fix:** Deploy infrastructure first
```bash
# GitHub Actions → Run workflow
# Select: infrastructure-only
```

---

## 📊 Success Criteria

After testing, you should see:

✅ **Automated Testing:**
- PRs trigger tests automatically
- Test results show in PR

✅ **Automated Deployment:**
- Push to `staging` → auto-deploy
- Push to `Sujie-CI/CD` → auto-deploy to production

✅ **Manual Control:**
- `services-only` works
- `infrastructure-only` works
- `full-deployment` works

✅ **State Management:**
- S3 bucket exists
- State file persists across runs
- State has version history

---

## 🎉 When Testing is Complete

1. **Document what works:**
   ```bash
   # Create test report
   echo "## CI/CD Test Results" > TEST-RESULTS.md
   echo "Date: $(date)" >> TEST-RESULTS.md
   echo "✅ All scenarios passed" >> TEST-RESULTS.md
   ```

2. **Merge to actual main (if needed):**
   ```bash
   git checkout main
   git merge Sujie-CI/CD
   git push origin main
   ```

3. **Update workflow for production:**
   - Change `Sujie-CI/CD` → `main`
   - Change `staging` → `develop`

Happy testing! 🚀