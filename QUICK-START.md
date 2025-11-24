# Quick Start: CI/CD with AWS Learner Lab

## 🚀 5-Minute Setup Guide

### Step 1: Start AWS Learner Lab

1. Go to your AWS Academy course
2. Click "Modules" → "Learner Lab"
3. Click "Start Lab" (wait for green indicator)
4. Click "AWS Details" → "Show"
5. Copy these credentials:
   ```
   AWS_ACCESS_KEY_ID
   AWS_SECRET_ACCESS_KEY
   AWS_SESSION_TOKEN
   ```

### Step 2: Configure GitHub Secrets

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add all three secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`

### Step 3: Create S3 Backend

Run locally (one-time setup):

```bash
# Configure AWS CLI with Learner Lab credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_REGION="us-west-2"

# Run setup script
cd config/scripts
chmod +x setup-s3-backend.sh
./setup-s3-backend.sh
```

Expected output:
```
✅ S3 bucket created: ticketing-terraform-state-{account-id}
✅ Versioning enabled
✅ Encryption enabled
```

### Step 4: First Deployment

1. Go to GitHub → Actions
2. Click "Deploy Ticketing System"
3. Click "Run workflow"
4. Select: **`full-deployment`**
5. Click "Run workflow"

Wait ~20-30 minutes. You'll see:
1. ✅ Build services
2. ✅ Terraform infrastructure
3. ✅ Deploy to ECS

### Step 5: Verify Deployment

```bash
# Get ALB DNS
aws elbv2 describe-load-balancers \
  --names ticketing-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Test endpoint
curl http://{ALB-DNS}/api/events
```

## 🔄 Daily Usage

### Scenario A: Code Change → Staging
```bash
git checkout develop
# ...make changes...
git commit -am "Update ticket logic"
git push origin develop
# 🤖 Auto-deploys to staging
```

### Scenario B: Code Change → Production
```bash
git checkout main
git merge develop
git push origin main
# 🤖 Auto-deploys to production
```

### Scenario C: Quick Bug Fix
```bash
# ...fix bug in code...
git commit -am "Fix null pointer"
git push origin main

# Manual trigger:
# GitHub Actions → services-only
```

## ⚠️ Learner Lab Reminders

### Every 4 Hours: Update Credentials
```bash
# Learner Lab credentials expire every 4 hours!
# Update GitHub Secrets before each deployment:
1. AWS Details → Show
2. GitHub Settings → Secrets → Update all 3
```

### When Lab Ends: Data is Lost
```bash
# On next lab session, redeploy everything:
GitHub Actions → full-deployment
```

## 🎯 Common Commands

### Check Deployment Status
```bash
gh run list --limit 5
```

### View Workflow Logs
```bash
gh run view --log
```

### Verify S3 State
```bash
aws s3 ls s3://ticketing-terraform-state-$(aws sts get-caller-identity --query Account --output text)/ticketing/
```

### Force Redeploy Service
```bash
aws ecs update-service \
  --cluster purchase-service-cluster \
  --service purchase-service \
  --force-new-deployment \
  --region us-west-2
```

## 🆘 Troubleshooting

### Error: "ExpiredToken"
**Solution**: Update GitHub Secrets with fresh credentials

### Error: "AccessDenied"
**Solution**: Make sure you're using LabRole (not other roles)

### Error: "Bucket does not exist"
**Solution**: Run `setup-s3-backend.sh` again

### Deployment Stuck
**Solution**: Check workflow logs with `gh run view --log`

## ✅ Success Checklist

- [ ] Learner Lab started (green indicator)
- [ ] GitHub Secrets configured (all 3)
- [ ] S3 backend created
- [ ] First full-deployment completed
- [ ] ALB DNS accessible
- [ ] Services responding to health checks

**You're ready to go!** 🎉

## 📚 Next Steps

- Read `CI-CD-DEMO-WORKFLOW.md` for detailed scenarios
- Set up branch protection rules for `main`
- Configure Slack/email notifications for deployments
- Add integration tests to test job

## 🔗 Useful Links

- [GitHub CLI](https://cli.github.com/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [Terraform Docs](https://www.terraform.io/docs)
