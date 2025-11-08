# AWS Learner Lab Deployment Guide

## The Problem

You're seeing "resource already exists" errors because:

1. ✅ Your cleanup script ran successfully and deleted AWS resources
2. ❌ But GitHub Actions had **cached** the old Terraform state
3. ❌ So Terraform thinks nothing exists and tries to create everything again
4. 💥 AWS says "these resources already exist!"

## The Solution (Smart Caching!)

### How It Works Now:

✅ **State is saved AFTER successful deployment** (for destroy to work)  
✅ **State is restored ONLY for destroy operations**  
✅ **Fresh deployments don't use cached state** (avoid "already exists" errors)  
✅ **Force cleanup available** if destroy fails

### Deployment Options:

#### 1. **full-deployment** (Deploy everything)

- Builds services
- Creates infrastructure
- Deploys containers
- **Saves state for future destroy**

#### 2. **infrastructure-only** (Just AWS resources)

- Creates VPC, ECS, RDS, etc.
- **Saves state for future destroy**

#### 3. **services-only** (Just update containers)

- Rebuilds Docker images
- Updates ECS services
- No infrastructure changes

#### 4. **destroy-infrastructure** (Clean shutdown)

- Uses cached Terraform state
- Properly destroys all resources
- If state missing → falls back to cleanup script

#### 5. **force-cleanup** (Nuclear option)

- No Terraform state needed
- Directly deletes AWS resources via API
- Use when state is lost/corrupted

---

## Quick Start Guide

### First Deployment:

```bash
# 1. Start AWS Learner Lab
# 2. Update GitHub Secrets (AWS credentials)
# 3. Run: full-deployment
```

### Update Services Only:

```bash
# After making code changes
# Run: services-only
```

### Clean Shutdown:

```bash
# Normal case (state exists)
# Run: destroy-infrastructure

# State lost/corrupted
# Run: force-cleanup
```

### Fix "Already Exists" Errors:

```bash
# 1. Run: force-cleanup
# 2. Clear cache: https://github.com/James-Zeyu-Li/Ticketing-Cloud-Deployment/actions/caches
# 3. Wait 2-3 minutes
# 4. Run: full-deployment
```

---

---

## How Terraform State Works Now

### 🎯 Smart Caching Strategy:

**During Deployment (`full-deployment` or `infrastructure-only`):**

1. ✅ No state restored (starts fresh)
2. ✅ Terraform checks AWS for existing resources
3. ✅ Creates only what's missing
4. ✅ **Saves state after success** with unique key: `terraform-state-{branch}-{run_number}`

**During Destroy (`destroy-infrastructure`):**

1. ✅ Restores most recent state for your branch
2. ✅ Terraform knows what to destroy
3. ✅ If state missing → automatic fallback to cleanup script
4. ✅ Cache naturally expires

**Force Cleanup (`force-cleanup`):**

1. ✅ No Terraform involved
2. ✅ Direct AWS API calls to delete resources
3. ✅ Works even with zero state

### Why This Works for Learner Lab:

| Scenario          | Old Approach (Broken)       | New Approach (Fixed)            |
| ----------------- | --------------------------- | ------------------------------- |
| Fresh deployment  | ❌ Used stale cache         | ✅ Checks AWS directly          |
| Updating services | ❌ Stale state issues       | ✅ No state needed              |
| Destroying infra  | ❌ No state = can't destroy | ✅ State saved from last deploy |
| Lost state        | ❌ Stuck                    | ✅ Fallback to cleanup script   |
| "Already exists"  | ❌ Common                   | ✅ Rare (only if AWS lags)      |

---

## Why No S3 Backend for Learner Lab?

**S3 Backend** is the professional way to store Terraform state, BUT:

- ❌ AWS Learner Lab sessions expire (4 hours)
- ❌ All resources including S3 buckets get deleted
- ❌ You'd need to manually recreate the S3 bucket each session
- ❌ You'd need to reconfigure Terraform backend each time

**For Learner Lab, it's simpler to:**

- ✅ Start fresh each deployment
- ✅ No state caching
- ✅ Run cleanup script between deployments

---

## Workflow for AWS Learner Lab

### Starting a New Session:

```bash
# 1. Start AWS Learner Lab
# 2. Get new credentials (they change each session!)
# 3. Update GitHub Secrets:
#    - AWS_ACCESS_KEY_ID
#    - AWS_SECRET_ACCESS_KEY
#    - AWS_SESSION_TOKEN

# 4. Clean up from last session (just in case)
cd config/scripts
./cleanup-aws-resources.sh

# 5. Deploy fresh
# Run GitHub Action: full-deployment
```

### Ending a Session:

```bash
# Optional: Clean up resources to save costs
# (Learner Lab will auto-cleanup anyway when session ends)
cd config/scripts
./cleanup-aws-resources.sh
```

---

## Troubleshooting

### ❌ "Resource already exists" error?

**Solution 1: Force Cleanup (Easiest)**

```bash
# In GitHub Actions:
1. Run workflow: force-cleanup
2. Wait 3 minutes
3. Run workflow: full-deployment
```

**Solution 2: Manual Cleanup**

```bash
# Locally:
cd config/scripts
./cleanup-aws-resources.sh

# Then clear GitHub cache:
# https://github.com/James-Zeyu-Li/Ticketing-Cloud-Deployment/actions/caches

# Wait 3 minutes, then deploy
```

### ❌ Terraform destroy not working?

**Don't worry! Auto-fallback is enabled:**

- If state is missing → cleanup script runs automatically
- OR manually run: `force-cleanup` workflow

### ❌ "No state found" warning?

**This is normal for fresh deployments!**

- State is only saved AFTER successful deployment
- First-time deploys won't have state (expected)

### ❌ Deployment succeeding but services unhealthy?

```bash
# Check these:
1. AWS credentials fresh? (expire every 4 hours)
2. RDS and ElastiCache fully started? (takes 5-10 mins)
3. Security groups allowing traffic?
4. Check ECS task logs in CloudWatch
```

### ⚠️ Resources taking long to delete?

**Normal deletion times:**

- Target Groups: 1-2 minutes
- Load Balancers: 2-3 minutes
- ElastiCache: 5-10 minutes
- RDS Clusters: 5-15 minutes

**Tip:** Run `force-cleanup`, then wait 5 minutes before redeploying.

---

## Changes Made to Fix This Issue

### 1. Smart State Caching

**File**: `.github/workflows/deploy.yml`

**Key Changes:**

- ✅ State saved ONLY after successful deployment
- ✅ State restored ONLY for destroy operations
- ✅ Fresh deployments bypass cache
- ✅ Fallback cleanup if state missing
- ✅ New `force-cleanup` option

**State Save** (after successful apply):

```yaml
- name: Save Terraform State
  if: github.event.inputs.action != 'destroy-infrastructure' && success()
  uses: actions/cache/save@v3
  with:
    path: |
      config/terraform/terraform.tfstate
      config/terraform/terraform.tfstate.backup
      config/terraform/.terraform
    key: terraform-state-${{ github.ref_name }}-${{ github.run_number }}
```

**State Restore** (only for destroy):

```yaml
- name: Restore Terraform State
  if: github.event.inputs.action == 'destroy-infrastructure'
  uses: actions/cache/restore@v3
  with:
    path: |
      config/terraform/terraform.tfstate
      config/terraform/terraform.tfstate.backup
      config/terraform/.terraform
    key: terraform-state-${{ github.ref_name }}
    restore-keys: |
      terraform-state-${{ github.ref_name }}
      terraform-state-
```

**Destroy Fallback**:

```yaml
- name: Terraform Destroy
  id: tf-destroy
  continue-on-error: true
  run: terraform destroy -auto-approve
  if: github.event.inputs.action == 'destroy-infrastructure'

- name: Fallback - Manual Cleanup
  if: steps.tf-destroy.outcome == 'failure'
  run: |
    echo "⚠️ Terraform destroy failed (no state)"
    echo "🧹 Using cleanup script instead..."
    ./config/scripts/cleanup-aws-resources.sh
```

### 2. New Force Cleanup Job

Complete resource deletion without Terraform state:

```yaml
force-cleanup:
  name: Force Cleanup AWS Resources
  runs-on: ubuntu-latest
  if: github.event.inputs.action == 'force-cleanup'
  steps:
    - name: Run Cleanup Script
      run: ./config/scripts/cleanup-aws-resources.sh
```

---

## Troubleshooting
