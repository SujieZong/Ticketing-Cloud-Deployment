# Ticketing Platform - CQRS Architecture

A high-performance ticketing system built with CQRS pattern, implementing read-write separation and event-driven architecture using AWS services.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Services](#services)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [GitHub Actions Setup](#github-actions-setup)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Architecture Overview

This system implements Command Query Responsibility Segregation (CQRS) with event-driven architecture:

**CQRS Pattern Implementation:**
- **Kafka** → **SNS + SQS** (AWS messaging services)
- **Redis** → **ElastiCache** (AWS managed Redis)
- **MySQL** → **RDS Aurora MySQL** (AWS managed database)

**Data Flow:**
```
Ticket Purchase Request → PurchaseService (Redis seat locking + SNS event publishing)
                              ↓
                    Amazon SNS Topic → SQS Queue
                              ↓
                   MessagePersistenceService (async MySQL write)
                              ↓
                   QueryService (MySQL data read)
```

### Infrastructure Components

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| Application Load Balancer (ALB) | HTTP routing with path-based rules | Routes `/purchase*`, `/query*`, `/events*` to respective services |
| ECS Auto Scaling | Dynamic task scaling based on CPU | purchase-service: 3-6 tasks (CPU > 60%), query/consumer: 1-3 tasks (CPU > 70%) |
| MySQL (RDS Aurora) | Primary data persistence | Aurora cluster: 1 writer + 1 reader replica (db.t4g.medium) |
| Redis (ElastiCache) | Seat state caching and distributed locks | Single-node cluster (cache.t3.small) |
| AWS SNS/SQS | Event publishing and async consumption | SNS: ticket-events topic, SQS: ticket-sql queue |

### Network Architecture Diagram

<img src="config/graphs/network_boundaries_v3.png" alt="Ticketing System Network Architecture" width="100%">

**Components:**
- **Security Groups:** Network access control
- **ECS Fargate:** Containerized microservices
- **ALB:** Load balancer for traffic distribution
- **RDS Aurora:** MySQL database with replica
- **ElastiCache:** Redis for caching and locking
- **SNS/SQS:** Event-driven messaging

## Services

| Service | Port | Responsibility | Key Technologies | Main Features |
|---------|------|----------------|------------------|---------------|
| PurchaseService | 8080 | Write operations - ticket purchases | Spring Boot, Redis, SNS | Redis seat locking, SNS event publishing, Input validation |
| QueryService | 8081 | Read operations - ticket queries | Spring Boot, JPA, MySQL | Multi-dimensional queries, Revenue analytics, Optimized reads |
| MessagePersistenceService | N/A | Event consumption & data projection | Spring Boot, SQS, MySQL | Async processing, Transactional consistency, Dead letter handling |

## API Documentation

**Base URL:** `http://<alb-dns-name>` (Get from: `terraform output -raw alb_dns_name`)

Complete API Reference: See `Ticketing-System-API-Tests.postman_collection.json`

### Quick Reference

#### Purchase Service (`/purchase/*`)
```bash
POST /purchase/api/v1/tickets  # Purchase ticket
GET /purchase/health           # Health check
```

#### Query Service (`/query/*`)
```bash
GET /query/api/v1/tickets              # Get all tickets
GET /query/api/v1/tickets/{id}         # Get ticket by ID
GET /query/api/v1/tickets/count/{eventId}  # Get count
GET /query/health                     # Health check
```

#### Message Persistence Service (`/events/*`)
```bash
GET /events/health  # Health check
```

### Testing Example
```bash
ALB_URL=$(cd config/terraform && terraform output -raw alb_dns_name)
curl -X POST http://$ALB_URL/purchase/api/v1/tickets \
  -H "Content-Type: application/json" \
  -d '{"venueId":"Venue1","eventId":"Event1","zoneId":1,"row":"A","column":"1"}'
sleep 2 && curl http://$ALB_URL/query/api/v1/tickets
```

## Deployment

### Prerequisites
- AWS CLI v2 configured with credentials
- Terraform 1.6+
- Docker Desktop
- jq (JSON processor)

### Deployment Steps

#### 1. Configure Terraform Variables
```bash
cd config/terraform
cp terraform.tfvars.template terraform.tfvars
# Edit terraform.tfvars: aws_region, aws_account_id, project_name, environment
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

#### 4. Terraform Apply - Create Infrastructure
```bash
cd config/terraform
terraform init
terraform apply -auto-approve
```
**Creates:** VPC, ECR (3 repos), RDS Aurora MySQL, ElastiCache Redis, SNS, SQS, ALB, ECS Fargate, Secrets Manager, CloudWatch

**Expected Time:** ~10-15 minutes (RDS Aurora and ElastiCache initialization are the slowest)

#### 5. Build and Push Images
```bash
cd config/scripts
./build-and-push.sh
```

**Deployment Flow:**
```
terraform.tfvars → aws configure → chmod +x → terraform apply → ./build-and-push.sh
```

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
**Note:** If health checks fail initially, wait another 2-3 minutes for containers to fully initialize.

### Update Services
```bash
# After making code changes, rebuild and redeploy
cd config/scripts
./build-and-push.sh
```
**Note:** The script uses the current git commit SHA as the image tag. If you want to track changes, commit before deploying.

## GitHub Actions Setup

### Required Secrets
Add to GitHub **Settings > Secrets and variables > Actions**:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `ALLOWED_IP`

### Manual Deployment
Go to **Actions** tab → "Deploy Ticketing System" → **Run workflow** → Choose action


## Cleanup

```bash
cd config/terraform
terraform destroy -auto-approve
```

**Note:** This will delete all AWS resources created by Terraform. Make sure to backup any important data before destroying.