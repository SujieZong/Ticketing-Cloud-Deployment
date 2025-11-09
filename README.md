# High-Concurrency Ticketing Platform - CQRS Architecture

A high-performance ticketing system built with CQRS pattern, implementing read-write separation and event-driven architecture using AWS services.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Services](#services)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

### CQRS Pattern Implementation

This system implements Command Query Responsibility Segregation (CQRS) with event-driven architecture:

```
Ticket Purchase Request → PurchaseService (Redis seat locking + SNS event publishing)
                              ↓
                    Amazon SNS Topic → SQS Queue
                              ↓
                   SqsConsumer (async MySQL write)
                              ↓
                   QueryService (MySQL data read)
```

### Technology Stack

- **Java 21** + **Spring Boot 3.x**
- **MySQL 8.x** (primary data store)
- **Redis 7.x** (seat state caching)
- **AWS SNS/SQS** (event messaging)
- **Docker** (containerization)
- **Terraform** (infrastructure as code)

### Service Architecture

| Service             | Port | Responsibility                                          | Technologies |
| ------------------- | ---- | ------------------------------------------------------- | ------------ |
| **PurchaseService** | 8080 | Handle ticket purchases, seat locking, event publishing | Redis + SNS  |
| **QueryService**    | 8081 | Provide ticket query and analytics APIs                 | MySQL + JPA  |
| **SqsConsumer**     | N/A  | Consume events and project data to MySQL                | SQS + MySQL  |

### Infrastructure Components

| Component                           | Purpose                                  | Configuration                                                                  |
| ----------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------ |
| **Application Load Balancer (ALB)** | HTTP routing with path-based rules       | Routes `/purchase*`, `/query*`, `/events*` to respective services              |
| **ECS Auto Scaling**                | Dynamic task scaling based on CPU        | purchase-service: 3-6 tasks (CPU > 60%), query/consumer: 1-3 tasks (CPU > 70%) |
| **MySQL (RDS Aurora)**              | Primary data persistence                 | Aurora cluster: 1 writer + 1 reader replica (db.t4g.medium)                    |
| **Redis (ElastiCache)**             | Seat state caching and distributed locks | Single-node cluster (cache.t3.small)                                           |
| **AWS SNS/SQS**                     | Event publishing and async consumption   | SNS: ticket-events topic, SQS: ticket-sql queue                                |

**Load Balancing**: ALB distributes traffic across ECS tasks with health checks  
**Auto Scaling**: Purchase service maintains 3-6 tasks (scales at CPU > 60%), Query/Consumer maintain 1-3 tasks (scale at CPU > 70%)  
**Database HA**: Aurora provides automatic failover from writer to reader replica

## Services

| Service             | Port | Responsibility                      | Key Technologies        | Main Features                                                     |
| ------------------- | ---- | ----------------------------------- | ----------------------- | ----------------------------------------------------------------- |
| **PurchaseService** | 8080 | Write operations - ticket purchases | Spring Boot, Redis, SNS | Redis seat locking, SNS event publishing, Input validation        |
| **QueryService**    | 8081 | Read operations - ticket queries    | Spring Boot, JPA, MySQL | Multi-dimensional queries, Revenue analytics, Optimized reads     |
| **SqsConsumer**     | N/A  | Event consumption & data projection | Spring Boot, SQS, MySQL | Async processing, Transactional consistency, Dead letter handling |

## API Documentation

**Base URL**: `http://<alb-dns-name>` (Get from: `terraform output -raw alb_dns_name`)

**Complete API Reference**: See `Ticketing-System-API-Tests.postman_collection.json` for full Postman collection.

### Quick Reference

#### Purchase Service (`/purchase/*`)

```bash
# Purchase a ticket
POST /purchase/api/v1/tickets
Body: {"venueId":"Venue1","eventId":"Event1","zoneId":1,"row":"A","column":"1"}

# Health check
GET /purchase/health
```

#### Query Service (`/query/*`)

```bash
# Get all tickets
GET /query/api/v1/tickets

# Get ticket by ticket ID (UUID)
GET /query/api/v1/tickets/{ticketId}
# Example: GET /query/api/v1/tickets/5b15a8a4-1f84-44dd-8f3d-9ae9de6e6d1b

# Get ticket count for event
GET /query/api/v1/tickets/count/{eventId}
# Example: GET /query/api/v1/tickets/count/Event1

# Get revenue for venue and event
GET /query/api/v1/tickets/revenue/{venueId}/{eventId}
# Example: GET /query/api/v1/tickets/revenue/Venue1/Event1

# Health check
GET /query/health
```

#### MQ Projection Service (`/events/*`)

```bash
# Health check (monitoring only)
GET /events/health
```

### Testing Example

```bash
# Get ALB URL
ALB_URL=$(cd config/terraform && terraform output -raw alb_dns_name)

# Purchase a ticket
curl -X POST http://$ALB_URL/purchase/api/v1/tickets \
  -H "Content-Type: application/json" \
  -d '{"venueId":"Venue1","eventId":"Event1","zoneId":1,"row":"A","column":"1"}'

# Query all tickets (wait 2s for async processing)
sleep 2 && curl http://$ALB_URL/query/api/v1/tickets
```

## Deployment

> 🎓 **Using AWS Learner Lab?** See [AWS-LEARNER-LAB-GUIDE.md](AWS-LEARNER-LAB-GUIDE.md) for special instructions!

### Prerequisites

- AWS CLI v2 configured with credentials
- Terraform 1.6+
- Docker Desktop
- jq (JSON processor)

### Deployment Options

You can deploy this system in multiple ways:

1. **GitHub Actions CI/CD** (Recommended): Automated deployment with 5 workflow options
2. **Local Deployment**: Using terminal commands for testing

#### GitHub Actions Workflows

| Workflow                      | Purpose            | Use Case                     |
| ----------------------------- | ------------------ | ---------------------------- |
| 🚀 **full-deployment**        | Deploy everything  | Fresh start, complete setup  |
| 🏗️ **infrastructure-only**    | AWS resources only | Test infra changes           |
| 🐳 **services-only**          | Update containers  | Code changes, quick updates  |
| 🗑️ **destroy-infrastructure** | Clean shutdown     | Proper resource cleanup      |
| 🧹 **force-cleanup**          | Nuclear cleanup    | When state is lost/corrupted |

**🔄 Auto-Import Feature (NEW!):**

- ✅ **Automatically imports existing resources** if deployment fails
- ✅ **Retries deployment** after import
- ✅ **Recovers from partial deployments** seamlessly
- ✅ Perfect for AWS Learner Lab & development environments
- 📖 See [AUTO-IMPORT-EXPLAINED.md](AUTO-IMPORT-EXPLAINED.md) for details

**Smart State Management:**

- ✅ State saved AFTER successful deployment (for destroy)
- ✅ State restored ONLY for destroy operations
- ✅ Fresh deployments bypass cache (avoid conflicts)
- ✅ Auto-fallback to cleanup script if state missing

---

## Local Deployment (For Testing)

### Deployment Steps

#### 1. Configure Terraform Variables

```bash
cd config/terraform
cp terraform.tfvars.template terraform.tfvars
nano terraform.tfvars  # Edit: aws_region, aws_account_id, project_name, environment
```

#### 2. Configure AWS Credentials

```bash
# For AWS Learner Lab users:
aws configure set aws_access_key_id YOUR_ACCESS_KEY
aws configure set aws_secret_access_key YOUR_SECRET_KEY
aws configure set aws_session_token YOUR_SESSION_TOKEN
aws configure set region us-west-2

# Verify
aws sts get-caller-identity
```

#### 3. Grant Script Permissions

```bash
chmod +x config/scripts/build-and-push.sh
chmod +x config/scripts/check-infrastructure.sh
```

#### 4. Create Infrastructure

```bash
cd config/terraform
terraform init
terraform apply -auto-approve
```

**Creates**: VPC, ECR (3 repos), RDS Aurora MySQL, ElastiCache Redis, SNS, SQS, ALB, ECS Fargate, Secrets Manager, CloudWatch

** Expected Time**: ~10-15 minutes (RDS Aurora and ElastiCache initialization are the slowest)

#### 5. Build & Deploy Services

```bash
cd config/scripts
./build-and-push.sh
```

---

### Deployment Flow

```
terraform.tfvars → aws configure → chmod +x → terraform apply → ./build-and-push.sh
```

---

### Verification

```bash
# Wait 3-5 minutes after build-and-push.sh completes, then verify:
./config/scripts/check-infrastructure.sh

# Check service health endpoints
ALB_URL=$(cd config/terraform && terraform output -raw alb_dns_name)
curl http://$ALB_URL/purchase/health
curl http://$ALB_URL/query/health
curl http://$ALB_URL/events/health
```

**Note**: If health checks fail initially, wait another 2-3 minutes for containers to fully initialize.

### Update Services

```bash
# After making code changes, rebuild and redeploy
cd config/scripts
./build-and-push.sh
```

**Note**: The script uses the current git commit SHA as the image tag. If you want to track changes, commit before deploying:

```bash
cd config/scripts && ./build-and-push.sh
```

### Cleanup

```bash
cd config/terraform
terraform destroy -auto-approve
```

---

## CI/CD Pipeline (Optional)

### Overview

This project includes a **GitHub Actions CI/CD pipeline** for automated build and deployment. The pipeline provides three deployment modes and is triggered **manually via GitHub's web interface**, not from the terminal.

**Important**: Local deployment via `terraform apply` + `./build-and-push.sh` remains the **recommended approach for AWS Learner Lab** due to session time limits. The CI/CD pipeline is provided for **demonstration and learning purposes**.

### Pipeline Modes

| Mode                    | Description                                                       | Duration  | Use Case                              |
| ----------------------- | ----------------------------------------------------------------- | --------- | ------------------------------------- |
| **infrastructure-only** | Run Terraform to create/update AWS infrastructure                 | 10-15 min | Initial setup, infrastructure changes |
| **services-only**       | Build & deploy Docker images only (assumes infrastructure exists) | 3-5 min   | Code updates, bug fixes               |
| **full-deployment**     | Run both Terraform and service deployment                         | 15-20 min | Complete automation demo, portfolio   |

### Setup (One-time)

#### 1. Add GitHub Secrets

Navigate to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

Add these secrets (get from AWS Learner Lab):

```
AWS_ACCESS_KEY_ID        = <your-access-key>
AWS_SECRET_ACCESS_KEY    = <your-secret-key>
AWS_SESSION_TOKEN        = <your-session-token>
AWS_ACCOUNT_ID           = <your-12-digit-account-id>
```

**Getting AWS Credentials from Learner Lab**:

1. Start AWS Learner Lab session
2. Click **"AWS Details"** button
3. Click **"Show"** next to AWS CLI credentials
4. Copy the values to GitHub Secrets

#### 2. Commit Workflow File

The workflow file has already been created at `.github/workflows/deploy.yml`. Commit and push it:

```bash
git add .github/workflows/deploy.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

### How to Trigger CI/CD Deployment

**⚠️ Important**: The workflow does **NOT** run automatically on `git push`. You must trigger it manually via GitHub's web interface.

#### Step-by-Step Trigger Process

**Step 1: Navigate to GitHub Actions** (Web Browser)

```
1. Open browser and go to: https://github.com/YOUR_USERNAME/YOUR_REPO_NAME
2. Click the "Actions" tab at the top of the page
```

**Step 2: Select Workflow**

```
3. In the left sidebar, click "Deploy Ticketing System"
4. You'll see a "Run workflow" dropdown button on the right side
```

**Step 3: Configure and Run**

```
5. Click the "Run workflow" dropdown button
6. Select branch: main
7. Choose deployment action from dropdown:
   - infrastructure-only: Creates AWS resources (VPC, RDS, Redis, ECS, ALB)
   - services-only: Builds Docker images and deploys to ECS ← Recommended
   - full-deployment: Runs both infrastructure and services
8. Click green "Run workflow" button
```

**Step 4: Monitor Progress**

```
9. Click on the running workflow (appears at top of page)
10. Watch real-time logs for each job:
    - build: Maven compilation + unit tests
    - terraform-infrastructure: Terraform apply (if selected)
    - deploy-services: Docker build + ECR push + ECS update
```

**Step 5: View Results**

```
11. Once complete, check the "Summary" tab for:
    - Deployment status
    - Image tags (git commit SHA)
    - ALB URL
    - Health check results
```

### Visual Workflow

```
GitHub Web UI (Browser)
         ↓
   [Run workflow] button
         ↓
┌────────────────────────────────┐
│  Select Deployment Mode        │
│  ○ infrastructure-only          │
│  ● services-only (selected)    │
│  ○ full-deployment             │
└────────────┬───────────────────┘
             ↓
┌────────────────────────────────┐
│ Job 1: Build Java Services     │
│ - Maven compile & test         │
│ - Upload JAR artifacts         │
└────────────┬───────────────────┘
             ↓
┌────────────────────────────────┐
│ Job 2: Terraform (conditional) │
│ - Restore state from cache     │
│ - terraform plan & apply       │
└────────────┬───────────────────┘
             ↓
┌────────────────────────────────┐
│ Job 3: Deploy Services         │
│ - Build Docker images          │
│ - Push to ECR                  │
│ - Update ECS tasks             │
│ - Run health checks            │
└────────────────────────────────┘
```

### Typical Workflows

#### For AWS Learner Lab Users (Recommended):

```bash
# 1. Deploy infrastructure locally (once per session)
cd config/terraform
terraform apply -auto-approve

# 2. For code updates, use CI/CD "services-only" mode
#    Go to: GitHub → Actions → Run workflow → Select "services-only"
#    This rebuilds Docker images and redeploys to ECS (3-5 min)

# 3. For quick iterations during development, use local script
cd config/scripts
./build-and-push.sh
```

**Why this approach?**

- AWS Learner Lab sessions expire after 4 hours
- Local Terraform is faster and more reliable for infrastructure setup
- CI/CD demonstrates DevOps skills without consuming session time on infrastructure recreation
- Local script is fastest for frequent code changes

#### For Portfolio/Demo Purposes:

```bash
# Show complete automated infrastructure deployment
# Go to: GitHub → Actions → Run workflow → Select "full-deployment"

# This demonstrates:
# - Infrastructure as Code (Terraform)
# - Automated build pipeline (Maven)
# - Container orchestration (Docker + ECS)
# - Zero-downtime deployment
# - Health monitoring
```

### Comparison: Local vs CI/CD

| Aspect             | Local Deployment             | GitHub Actions CI/CD                                 |
| ------------------ | ---------------------------- | ---------------------------------------------------- |
| **Trigger**        | Terminal commands            | GitHub web interface                                 |
| **Infrastructure** | `terraform apply` (local)    | Terraform in GitHub Actions                          |
| **Speed**          | Fast (5-10 min total)        | Slow (15-20 min full) / Fast (3-5 min services-only) |
| **AWS Credits**    | Moderate usage               | Higher usage (clean builds)                          |
| **State Storage**  | Local `terraform.tfstate`    | GitHub Actions cache                                 |
| **Best For**       | Development, AWS Learner Lab | Demos, portfolio, team collaboration                 |
| **Control**        | Immediate execution          | Requires web browser                                 |
| **Learning Value** | Practical deployment         | DevOps best practices                                |

### Pipeline Architecture Details

#### Terraform State Management

The CI/CD pipeline uses **GitHub Actions cache** for Terraform state storage:

**Advantages**:

- ✅ No S3 bucket setup required
- ✅ Zero additional AWS costs
- ✅ Suitable for learning/demo projects
- ✅ Simple configuration

**Limitations**:

- ⚠️ Cache expires after 7 days of inactivity
- ⚠️ No state locking (avoid concurrent workflow runs)
- ⚠️ Not recommended for production (use S3 backend with DynamoDB locking instead)

**State Recovery**: If cache expires and state is lost:

```bash
# Option 1: Run Terraform locally to recreate state
cd config/terraform
terraform apply

# Option 2: Re-run "infrastructure-only" mode in GitHub Actions
# The workflow will recreate infrastructure and cache new state

# Option 3: Import existing resources (advanced)
terraform import aws_vpc.main vpc-xxxxx
terraform import aws_ecs_cluster.main ticketing-prod-cluster
# ... repeat for all resources
```

#### Image Tagging Strategy

The pipeline uses **Git commit SHA** for image tags:

```bash
# Automatically tagged in CI/CD
docker tag purchase-service:latest <ecr-url>/purchase-service:a1b2c3d4
docker tag purchase-service:latest <ecr-url>/purchase-service:latest

# Benefits:
# - Track exactly which code version is deployed
# - Enable rollbacks to specific commits
# - Audit trail for deployments
```

### Demo Script for Presentations

When demonstrating the CI/CD pipeline to professors/reviewers:

#### Part 1: Show Local Deployment Still Works (2 min)

```bash
# Terminal demonstration
echo "=== Traditional Local Deployment ==="
cd config/scripts
./build-and-push.sh

# Talking point:
# "This is our traditional deployment method. Developers can still use this
#  for quick iterations. Now let me show you the automated CI/CD pipeline..."
```

#### Part 2: Trigger CI/CD Workflow (1 min)

1. Open browser → GitHub repository
2. Navigate to **Actions** tab
3. Click **Deploy Ticketing System** (left sidebar)
4. Click **Run workflow** dropdown (right side)
5. Select: **services-only** (fastest for demo)
6. Click green **Run workflow** button

**Talking point**:

> "The pipeline is triggered manually here for cost control, but in production this would run automatically on every push to main. Let me show you each stage..."

#### Part 3: Walk Through Pipeline Stages (3 min)

Click on the running workflow to show live logs:

**Stage 1: Build & Test**

```
🔨 Building PurchaseService...
🔨 Building QueryService...
🧪 Running unit tests...
✅ All tests passed!
```

**Talking point**: "First, we compile all microservices and run unit tests to catch bugs before deployment."

**Stage 2: Build Docker Images**

```
🐳 Building and pushing PurchaseService...
🐳 Building and pushing QueryService...
✅ Images pushed to ECR!
```

**Talking point**: "Next, we containerize each service and push to AWS ECR for deployment."

**Stage 3: Deploy to ECS**

```
♻️ Updating ECS services...
⏳ Waiting for services to stabilize...
🏥 Running health checks...
✅ All services healthy!
```

**Talking point**: "Finally, we update ECS to pull new images. This is zero-downtime deployment using rolling updates."

#### Part 4: Show Results (1 min)

Open the **Summary** tab and point out:

- ✅ All checks passed
- 🏷️ Image tag: `abc123def` (git commit SHA)
- 🔗 ALB URL with health check commands
- 📊 Deployment duration

**Talking point**:

> "This workflow demonstrates industry-standard DevOps practices: automated testing, containerization, and infrastructure as code. The entire process is tracked, auditable, and repeatable."

### Troubleshooting CI/CD

**"Run workflow button not visible"**

- Ensure `.github/workflows/deploy.yml` is pushed to `main` branch
- Check file is in `.github/workflows/` directory (not `github/workflows`)
- Refresh GitHub page and wait 1-2 minutes for GitHub to detect workflow

**"Workflow doesn't have workflow_dispatch trigger"**

- Verify YAML has `on: workflow_dispatch:` section at the top
- Check YAML indentation is correct (use spaces, not tabs)
- Commit and push any changes to the workflow file

**"AWS credentials error during workflow"**

- Update GitHub Secrets with fresh AWS Learner Lab credentials
- Verify secret names match exactly: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_ACCOUNT_ID`
- Test credentials work locally: `aws sts get-caller-identity`
- AWS Learner Lab credentials expire after 4 hours - refresh them

**"Terraform state not found"**

- First time running: Expected - workflow will create new state
- Cache expired: Run Terraform locally first or select "infrastructure-only" mode
- State corruption: Delete cache and re-run "infrastructure-only" mode

**"ECS service not found"**

- Infrastructure doesn't exist yet
- Run "infrastructure-only" or "full-deployment" mode first
- Or deploy infrastructure locally: `cd config/terraform && terraform apply`

**"Docker build timeout or failure"**

- Maven dependencies may take long to download on first build
- Retry workflow - subsequent runs will use cached dependencies
- Check CloudWatch Logs for detailed error messages

**"Health checks failing after deployment"**

- Wait an additional 2-3 minutes for containers to fully start
- Check ECS task logs in CloudWatch for application errors
- Verify security groups allow ALB → ECS communication
- Ensure RDS and Redis are accessible from ECS tasks

### Best Practices

#### For AWS Learner Lab Environment

**Recommended Workflow**:

1. **Infrastructure**: Deploy locally with `terraform apply` (once per session)
2. **Development**: Use local `./build-and-push.sh` for rapid iterations
3. **Demonstration**: Use GitHub Actions "services-only" for showing CI/CD to reviewers
4. **Documentation**: Include "full-deployment" workflow screenshot in project portfolio

**Why this hybrid approach?**

- ⏱️ Learner Lab sessions are time-limited (4 hours)
- 💰 Minimize AWS credit consumption
- 🚀 Faster development cycle with local deployment
- 🎓 Still demonstrates CI/CD knowledge for educational purposes
- 🔄 Flexibility to use either method based on situation

#### For Production Projects

If deploying to a real AWS account (not Learner Lab):

1. **Use S3 Backend for Terraform State**:

```hcl
# config/terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "ticketing/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

2. **Enable Automatic Triggers**:

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main] # Auto-deploy on push
  workflow_dispatch: # Keep manual trigger option
```

3. **Add Approval Gates**:

```yaml
environment:
  name: production
  url: ${{ steps.deploy.outputs.url }}
  # Requires manual approval in GitHub Settings
```

4. **Implement Blue-Green Deployment**:

- Use ECS task set for blue-green deployments
- Route 10% traffic to new version first
- Gradually shift traffic after health checks pass

### CI/CD Benefits Demonstrated

This CI/CD implementation showcases:

✅ **Infrastructure as Code**: Terraform manages all AWS resources  
✅ **Automated Testing**: Maven runs unit tests before deployment  
✅ **Container Orchestration**: Docker + ECS for consistent environments  
✅ **Zero-Downtime Deployment**: Rolling updates with health checks  
✅ **Traceability**: Git SHA tags track deployed versions  
✅ **Flexibility**: Multiple deployment modes for different scenarios  
✅ **Cost Awareness**: Manual triggers prevent unnecessary AWS charges  
✅ **Industry Standards**: GitHub Actions, Docker, Terraform best practices

### Additional Resources

- **GitHub Actions Docs**: https://docs.github.com/actions
- **Terraform Best Practices**: https://www.terraform-best-practices.com
- **ECS Blue-Green Deployment**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html
- **Docker Multi-Stage Builds**: https://docs.docker.com/build/building/multi-stage/

---

## Troubleshooting

### Common Issues

**Service Health Check Failures**

- Verify AWS credentials: `aws sts get-caller-identity`
- Check CloudWatch logs for error messages
- Ensure security groups allow ALB → ECS communication

**Database Connection Errors**

- Verify RDS cluster status in AWS Console
- Check Secrets Manager for correct credentials
- Confirm VPC and subnet configuration

**Message Processing Issues**

- Check SQS queue has messages: `aws sqs get-queue-attributes`
- Review CloudWatch logs for SQS consumer errors
- Verify SNS topic subscriptions exist

**Terraform Errors - "Resource Already Exists"**

If you see errors like:

```
Error: creating ECS Cluster: ResourceAlreadyExistsException
Error: creating RDS Cluster: DBClusterAlreadyExistsFault
Error: creating Target Group: DuplicateTargetGroupName
```

**✅ Solution**: The CI/CD pipeline now has **Auto-Import** feature!

1. **First Time**: Just run the workflow again - it will automatically import existing resources
2. **Persistent Issues**: Use the `force-cleanup` workflow action to delete all resources first
3. **Manual Import**: Run `./config/scripts/test-imports.sh` to test import commands locally

📖 See [AUTO-IMPORT-EXPLAINED.md](AUTO-IMPORT-EXPLAINED.md) for technical details.

**Terraform State Issues**

```bash
# If state is corrupted or lost
cd config/terraform

# Option 1: Refresh state from AWS
terraform refresh

# Option 2: Import existing resources
terraform import 'module.ecr.aws_ecr_repository.repos["purchase-service"]' purchase-service
# ... (see COMPLETE-IMPORT-LIST.md for all resources)

# Option 3: Clean start (⚠️ deletes everything!)
./config/scripts/cleanup-aws-resources.sh
```

**GitHub Actions Failures**

```bash
# Check workflow logs in: GitHub → Actions → <failed-run>

# Common fixes:
1. Update AWS credentials in GitHub Secrets (they expire in Learner Lab)
2. Wait for previous workflow to complete before running new one
3. Use "force-cleanup" if resources are stuck in bad state
4. Check CloudWatch Logs for application errors
```

### Monitoring

- **CloudWatch Logs**: `/ecs/{service-name}` log groups
- **Health Checks**: `curl http://<alb>/purchase/health`
- **Infrastructure Script**: `./config/scripts/check-infrastructure.sh`
- **Import Test**: `./config/scripts/test-imports.sh` (test resource imports locally)

### Getting Help

1. **Check Logs**:

   ```bash
   # ECS task logs
   aws logs tail /ecs/purchase-service --follow

   # Recent deployment errors
   cd config/terraform && terraform show
   ```

2. **Verify Resources**:

   ```bash
   ./config/scripts/check-infrastructure.sh
   ```

3. **Test Imports**:

   ```bash
   chmod +x config/scripts/test-imports.sh
   ./config/scripts/test-imports.sh
   ```

4. **Documentation**:
   - [AWS Learner Lab Guide](AWS-LEARNER-LAB-GUIDE.md)
   - [Auto-Import Documentation](AUTO-IMPORT-EXPLAINED.md)
   - [Complete Import Resource List](COMPLETE-IMPORT-LIST.md)
