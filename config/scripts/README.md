# Configuration Scripts

This directory contains scripts for managing AWS infrastructure and CI/CD setup.

## 📁 Scripts Overview

### `setup-s3-backend.sh`

**Purpose**: Creates S3 bucket for Terraform state management

**When to run**:

- Before first deployment
- One-time setup per AWS account

**Usage**:

```bash
cd config/scripts
./setup-s3-backend.sh
```

**What it does**:

- Creates S3 bucket: `ticketing-terraform-state-{account-id}`
- Enables versioning (state history)
- Enables encryption (AES256)
- Blocks public access
- Displays backend configuration

**Requirements**:

- Valid AWS credentials in environment
- Permissions to create S3 buckets (LabRole has this)

---

### `cleanup-aws-resources.sh`

**Purpose**: Emergency cleanup of all AWS resources

**When to run**:

- When Terraform state is corrupted
- Force cleanup via GitHub Actions (`force-cleanup` option)
- Manual cleanup needed

**Usage**:

```bash
cd config/scripts
./cleanup-aws-resources.sh
```

**⚠️ Warning**: This deletes everything!

- ECS clusters and services
- Application Load Balancer
- RDS Aurora cluster
- ElastiCache Redis
- ECR repositories
- VPC and networking

---

### `build-and-push.sh`

**Purpose**: Build and push Docker images to ECR

**When to run**:

- Local development testing
- Manual image builds

**Usage**:

```bash
cd config/scripts
./build-and-push.sh
```

**What it does**:

- Builds all service Docker images
- Pushes to ECR with latest tag
- Supports multi-arch builds

---

### `check-infrastructure.sh`

**Purpose**: Verify infrastructure status

**When to run**:

- After deployment
- Troubleshooting
- Pre-deployment checks

**Usage**:

```bash
cd config/scripts
./check-infrastructure.sh
```

**What it checks**:

- ECS cluster status
- Service health
- ALB target health
- RDS connectivity
- Redis availability

---

## 🔧 AWS Learner Lab Considerations

### LabRole Permissions

All scripts work with LabRole, which has:

- ✅ S3 full access
- ✅ ECS full access
- ✅ EC2 full access
- ✅ RDS full access
- ✅ ElastiCache access
- ❌ No IAM role creation (use existing roles)

### Session Management

```bash
# Set credentials before running scripts
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_REGION="us-west-2"
```

### State Management

- Scripts use S3 for state persistence
- State survives within lab session
- State deleted when lab ends
- Must redeploy on new lab session

---

## 🚀 Quick Start Workflow

1. **Setup S3 Backend** (one-time)

   ```bash
   ./setup-s3-backend.sh
   ```

2. **Deploy via GitHub Actions**

   - Go to GitHub Actions
   - Run workflow with `full-deployment`

3. **Verify Infrastructure**

   ```bash
   ./check-infrastructure.sh
   ```

4. **If issues occur**
   ```bash
   ./cleanup-aws-resources.sh
   # Then redeploy
   ```

---

## 📝 Script Maintenance

### Adding New Services

Edit these scripts when adding services:

- `build-and-push.sh` - Add Docker build
- `cleanup-aws-resources.sh` - Add cleanup logic
- `check-infrastructure.sh` - Add health checks

### Testing Scripts

```bash
# Dry run (some scripts support this)
./cleanup-aws-resources.sh --dry-run

# Verbose output
./setup-s3-backend.sh --verbose
```

---

## 🔍 Troubleshooting

### Script Fails with "Permission Denied"

```bash
chmod +x *.sh
```

### AWS Credentials Not Found

```bash
# Check credentials
aws sts get-caller-identity

# If expired, update from Learner Lab
# AWS Details → Show → Copy new credentials
```

### S3 Bucket Already Exists

```bash
# Script handles this gracefully
# Will verify existing bucket and continue
```

### Cleanup Script Hangs

```bash
# Some resources take time to delete
# RDS: ~5 minutes
# ElastiCache: ~3 minutes
# ALB: ~2 minutes

# Be patient, or:
Ctrl+C and check AWS Console
```

---

## 📚 Related Documentation

- [QUICK-START.md](../../QUICK-START.md) - Quick setup guide
- [CI-CD-DEMO-WORKFLOW.md](../../CI-CD-DEMO-WORKFLOW.md) - Detailed workflows
- [terraform/](../terraform/) - Infrastructure as Code

---

## 💡 Tips

1. **Always run setup-s3-backend.sh first**

   - Required for state management
   - Safe to run multiple times

2. **Use GitHub Actions for deployments**

   - More reliable than manual scripts
   - Includes error handling
   - Logs preserved

3. **Keep credentials fresh**

   - Learner Lab expires every 4 hours
   - Update before running scripts

4. **Verify before cleanup**
   - Check what exists: `aws ecs list-clusters`
   - Cleanup is destructive!

---

**Need help?** Check the main README or open an issue on GitHub.
