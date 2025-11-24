# CI/CD Demo Workflow for AWS Learner Lab

This guide demonstrates the complete CI/CD workflow for the Ticketing System using AWS Learner Lab.

## 🎯 Overview

This CI/CD pipeline includes:

- ✅ **Automated Testing** on every push/PR
- 🚀 **Automated Deployment** to staging (develop) and production (main)
- 🎛️ **Manual Control** for infrastructure changes
- 📦 **S3 State Management** for Terraform persistence
- 🏷️ **Environment Tagging** (staging/production/manual)

## 📋 Prerequisites

### 1. AWS Learner Lab Setup

- Active AWS Learner Lab session
- Valid credentials (automatically refreshed every 4 hours)
- LabRole with necessary permissions

### 2. GitHub Secrets Configuration

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

```
AWS_ACCESS_KEY_ID       = <from AWS Learner Lab>
AWS_SECRET_ACCESS_KEY   = <from AWS Learner Lab>
AWS_SESSION_TOKEN       = <from AWS Learner Lab>
```

**Important**: Update these secrets every time you start a new Learner Lab session!

### 3. Create S3 Backend (One-Time Setup)

Run this script locally before first deployment:

```bash
cd config/scripts
chmod +x setup-s3-backend.sh
./setup-s3-backend.sh
```

This creates:

- S3 bucket: `ticketing-terraform-state-{account-id}`
- Versioning enabled (state history)
- Encryption enabled (AES256)
- Public access blocked

## 🔄 CI/CD Workflow Scenarios

### Scenario 1: Feature Development (Automated)

**Goal**: Develop a new feature with automatic testing

```bash
# 1. Create feature branch
git checkout -b feature/new-ticket-validation

# 2. Make changes to PurchaseService
vim PurchaseService/src/main/java/...

# 3. Commit and push
git add .
git commit -m "Add ticket quantity validation"
git push origin feature/new-ticket-validation

# 4. Create Pull Request to main
# → ✅ Tests run automatically
# → ❌ If tests fail, PR is blocked
# → ✅ If tests pass, ready to merge
```

**What happens automatically:**

1. GitHub Actions triggers on PR creation
2. `test` job runs all unit tests
3. Results show in PR (✅ or ❌)
4. No deployment (only testing)

---

### Scenario 2: Deploy to Staging (Automated)

**Goal**: Automatically deploy to staging environment

```bash
# 1. Merge feature to develop branch
git checkout develop
git merge feature/new-ticket-validation
git push origin develop

# 🤖 AUTOMATIC DEPLOYMENT STARTS
```

**What happens automatically:**

1. ✅ Run all tests
2. 🏗️ Build Java services (Maven)
3. 📦 Build Docker images
4. ⬆️ Push to ECR with tags: `{commit-sha}`, `staging`, `latest`
5. ♻️ Update ECS services (zero-downtime rolling update)
6. 📍 Terraform state read from S3
7. 💾 Terraform state updated in S3

**Timeline**: ~5-10 minutes

**Verification**:

```bash
# Check workflow status
gh run list --branch develop

# Check ECS services
aws ecs describe-services \
  --cluster purchase-service-cluster \
  --services purchase-service \
  --region us-west-2

# Test staging endpoint
curl http://{ALB-DNS}/api/health
```

---

### Scenario 3: Deploy to Production (Automated)

**Goal**: Promote tested code to production

```bash
# 1. Merge develop to main
git checkout main
git merge develop
git push origin main

# 🤖 PRODUCTION DEPLOYMENT STARTS
```

**What happens automatically:**

1. ✅ Run all tests
2. 🏗️ Build Java services
3. 📦 Build Docker images
4. ⬆️ Push to ECR with tags: `{commit-sha}`, `production`, `latest`
5. ♻️ Update ECS production services
6. 📍 Read state from S3
7. 💾 Update state in S3

**Timeline**: ~5-10 minutes

---

### Scenario 4: Infrastructure Changes (Manual)

**Goal**: Update infrastructure (VPC, RDS, ElastiCache, etc.)

```bash
# 1. Make changes to Terraform files
vim config/terraform/variables-rds.tf

# 2. Commit and push
git add .
git commit -m "Increase RDS instance size"
git push origin main
```

**Manual deployment required**:

1. Go to GitHub Actions
2. Click "Deploy Ticketing System"
3. Click "Run workflow"
4. Select: **`infrastructure-only`**
5. Click "Run workflow"

**What happens:**

1. 📍 Read state from S3
2. 🔄 Terraform plan (show changes)
3. ✅ Terraform apply (update infrastructure)
4. 💾 Save updated state to S3
5. ❌ No service redeployment

**Timeline**: ~15-20 minutes

---

### Scenario 5: Services-Only Update (Manual)

**Goal**: Update only application code, keep infrastructure unchanged

**Use when:**

- Bug fix in Java code
- Configuration change in `application.yml`
- Dependency update in `pom.xml`
- Code refactoring

```bash
# 1. Make code changes
vim QueryService/src/main/java/.../TicketController.java

# 2. Commit and push
git commit -am "Fix: Handle empty event list"
git push origin main
```

**Manual deployment**:

1. Go to GitHub Actions
2. Select: **`services-only`**
3. Run workflow

**What happens:**

1. 🏗️ Build services
2. 📦 Build Docker images
3. ⬆️ Push to ECR
4. ♻️ Update ECS services
5. ❌ No Terraform run (infrastructure untouched)
6. ✅ State preserved in S3

**Timeline**: ~5-7 minutes

---

### Scenario 6: Full Deployment (Manual)

**Goal**: Deploy everything (infrastructure + services)

**Use when:**

- First-time deployment
- Major version upgrade
- Combined infrastructure and code changes

1. Go to GitHub Actions
2. Select: **`full-deployment`**
3. Run workflow

**What happens:**

1. 🏗️ Build services
2. 🏗️ Terraform apply (infrastructure)
3. 📦 Build Docker images
4. ⬆️ Push to ECR
5. ♻️ Deploy services to ECS
6. 💾 State saved to S3

**Timeline**: ~20-30 minutes

---

### Scenario 7: Destroy Infrastructure (Manual)

**Goal**: Clean up all AWS resources

**⚠️ Warning**: This deletes everything!

1. Go to GitHub Actions
2. Select: **`destroy-infrastructure`**
3. Run workflow

**What happens:**

1. 📍 Read state from S3
2. 💥 Terraform destroy (delete all resources)
3. 💾 Update state in S3 (empty state)
4. 🧹 Cleanup script (if Terraform fails)

---

### Scenario 8: Force Cleanup (Emergency)

**Goal**: Nuclear option - delete everything when Terraform is broken

1. Go to GitHub Actions
2. Select: **`force-cleanup`**
3. Run workflow

**What happens:**

1. 🧹 Run `cleanup-aws-resources.sh`
2. 🗑️ Delete ECS clusters
3. 🗑️ Delete ALB
4. 🗑️ Delete RDS
5. 🗑️ Delete ElastiCache
6. 🗑️ Delete ECR repositories
7. 🗑️ Delete VPC

---

## 📊 Workflow Decision Tree

```
Code Change Made
    ↓
Is it infrastructure code (Terraform)?
    ├─ YES → Push to main → Manual: infrastructure-only
    └─ NO → Is it urgent bug fix?
            ├─ YES → Push to main → Manual: services-only
            └─ NO → Regular feature development
                    ↓
                Push to feature branch
                    ↓
                Create PR to main
                    ↓
                ✅ Tests run automatically
                    ↓
                Merge to develop
                    ↓
                🤖 Auto-deploy to staging
                    ↓
                Test staging
                    ↓
                Merge to main
                    ↓
                🤖 Auto-deploy to production
```

## 🔍 Monitoring & Verification

### Check Workflow Status

```bash
# List recent workflows
gh run list

# Watch specific run
gh run watch

# View logs
gh run view <run-id> --log
```

### Check S3 State

```bash
# List state files
aws s3 ls s3://ticketing-terraform-state-{account-id}/ticketing/

# Download current state
aws s3 cp s3://ticketing-terraform-state-{account-id}/ticketing/terraform.tfstate ./

# List all versions
aws s3api list-object-versions \
  --bucket ticketing-terraform-state-{account-id} \
  --prefix ticketing/terraform.tfstate
```

### Check Deployed Services

```bash
# ECS service status
aws ecs describe-services \
  --cluster purchase-service-cluster \
  --services purchase-service \
  --region us-west-2

# Get ALB DNS
aws elbv2 describe-load-balancers \
  --names ticketing-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Test health endpoint
curl http://{ALB-DNS}/api/health
```

### View Logs

```bash
# ECS task logs
aws logs tail /ecs/purchase-service --follow

# CloudWatch logs
aws logs filter-log-events \
  --log-group-name /ecs/purchase-service \
  --start-time $(date -u -d '5 minutes ago' +%s)000
```

## 🎓 AWS Learner Lab Limitations

### What Works ✅

- S3 bucket for state (created automatically)
- S3 versioning (state history)
- Automated CI/CD triggers
- ECS deployments
- ECR image storage

### What Doesn't Work ❌

- **DynamoDB state locking**: Not available in Learner Lab
  - **Impact**: Concurrent deployments may conflict
  - **Solution**: Run one deployment at a time
- **Persistent state across sessions**: Deleted when lab ends
  - **Impact**: Must redeploy when starting new session
  - **Solution**: Use `import` step in workflow

### Session Management

```bash
# Update GitHub Secrets every 4 hours
# Learner Lab → AWS Details → Show

AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
```

## 🚨 Troubleshooting

### Problem: Tests fail on PR

```bash
# Run tests locally
cd PurchaseService
mvn test

# Fix issues and commit
git commit -am "Fix failing tests"
git push
```

### Problem: Deployment fails

```bash
# Check workflow logs
gh run view <run-id> --log

# Check AWS credentials
aws sts get-caller-identity

# Verify S3 bucket exists
aws s3 ls s3://ticketing-terraform-state-{account-id}/
```

### Problem: State conflict

```bash
# Manually sync state
cd config/terraform
terraform init -reconfigure
terraform state pull > terraform.tfstate
terraform state push terraform.tfstate
```

### Problem: ECS service won't update

```bash
# Force new deployment
aws ecs update-service \
  --cluster purchase-service-cluster \
  --service purchase-service \
  --force-new-deployment \
  --region us-west-2
```

## 📈 Best Practices

1. **Always test on develop first**

   - Push to develop → auto-deploy to staging
   - Test thoroughly
   - Then merge to main → auto-deploy to production

2. **Keep infrastructure changes separate**

   - Use manual `infrastructure-only` trigger
   - Review Terraform plan carefully
   - Infrastructure changes are slow (15-20 min)

3. **Use services-only for quick updates**

   - Bug fixes, code changes
   - Much faster (5-7 min)
   - No infrastructure risk

4. **Monitor S3 state regularly**

   - Verify state exists before large changes
   - Use versioning to rollback if needed

5. **Update Learner Lab credentials**
   - Set calendar reminder every 3 hours
   - Update GitHub Secrets immediately
   - Prevents failed deployments

## 🎉 Summary

You now have a **production-grade CI/CD pipeline** with:

- ✅ Automated testing on every PR
- 🚀 Automated deployments (staging & production)
- 📦 Persistent state management (S3)
- 🎛️ Manual control for infrastructure
- 🏷️ Environment tagging
- 🔄 Zero-downtime rolling updates

**Happy deploying!** 🚀
