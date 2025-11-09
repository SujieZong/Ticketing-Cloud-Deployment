# 📋 Complete Import List - All Resources

## Resources Automatically Imported by CI/CD

When deployment fails with "already exists" errors, the workflow automatically imports these resources:

---

### 🐳 Container & Compute

| Resource               | Terraform Address                                             | AWS Identifier          |
| ---------------------- | ------------------------------------------------------------- | ----------------------- |
| ECR - Purchase Service | `module.ecr["purchase-service"].aws_ecr_repository.this`      | `purchase-service`      |
| ECR - Query Service    | `module.ecr["query-service"].aws_ecr_repository.this`         | `query-service`         |
| ECR - MQ Service       | `module.ecr["mq-projection-service"].aws_ecr_repository.this` | `mq-projection-service` |

---

### ⚖️ Load Balancing

| Resource                      | Terraform Address                                                         | AWS Identifier                   |
| ----------------------------- | ------------------------------------------------------------------------- | -------------------------------- |
| **Application Load Balancer** | `module.shared_alb.aws_lb.shared`                                         | `ticketing-alb` (ARN)            |
| Target Group - Purchase       | `module.shared_alb.aws_lb_target_group.services["purchase-service"]`      | `purchase-service-tg` (ARN)      |
| Target Group - Query          | `module.shared_alb.aws_lb_target_group.services["query-service"]`         | `query-service-tg` (ARN)         |
| Target Group - MQ             | `module.shared_alb.aws_lb_target_group.services["mq-projection-service"]` | `mq-projection-service-tg` (ARN) |

---

### 🔒 Security Groups

| Resource               | Terraform Address                            | AWS Identifier               |
| ---------------------- | -------------------------------------------- | ---------------------------- |
| ALB Security Group     | `module.network.aws_security_group.alb_sg`   | `ticketing-alb-sg` (SG ID)   |
| **ECS Security Group** | `module.network.aws_security_group.this`     | `ticketing-ecs-sg` (SG ID)   |
| RDS Security Group     | `module.network.aws_security_group.rds_sg`   | `ticketing-rds-sg` (SG ID)   |
| Redis Security Group   | `module.network.aws_security_group.redis_sg` | `ticketing-redis-sg` (SG ID) |

---

### 📊 Logging & Monitoring

| Resource              | Terraform Address                                                       | AWS Identifier               |
| --------------------- | ----------------------------------------------------------------------- | ---------------------------- |
| Purchase Service Logs | `module.logging["purchase-service"].aws_cloudwatch_log_group.this`      | `/ecs/purchase-service`      |
| Query Service Logs    | `module.logging["query-service"].aws_cloudwatch_log_group.this`         | `/ecs/query-service`         |
| MQ Service Logs       | `module.logging["mq-projection-service"].aws_cloudwatch_log_group.this` | `/ecs/mq-projection-service` |

---

### 🔐 Secrets Management

| Resource             | Terraform Address                                    | AWS Identifier                |
| -------------------- | ---------------------------------------------------- | ----------------------------- |
| Redis Credentials    | `module.elasticache.aws_secretsmanager_secret.redis` | `ticketing-redis-credentials` |
| Database Credentials | `module.rds.aws_secretsmanager_secret.db`            | `ticketing-db-credentials`    |

---

### 💾 ElastiCache (Redis)

| Resource              | Terraform Address                                         | AWS Identifier                 |
| --------------------- | --------------------------------------------------------- | ------------------------------ |
| Cache Subnet Group    | `module.elasticache.aws_elasticache_subnet_group.this`    | `ticketing-cache-subnet-group` |
| Cache Parameter Group | `module.elasticache.aws_elasticache_parameter_group.this` | `ticketing-redis-params`       |

---

### 🗄️ RDS (Aurora MySQL)

| Resource                   | Terraform Address                                 | AWS Identifier                  |
| -------------------------- | ------------------------------------------------- | ------------------------------- |
| DB Subnet Group            | `module.rds.aws_db_subnet_group.default`          | `ticketing-aurora-subnet-group` |
| DB Cluster Parameter Group | `module.rds.aws_rds_cluster_parameter_group.this` | `ticketing-mysql-params`        |

---

### 🔑 IAM

| Resource                | Terraform Address                                  | AWS Identifier              |
| ----------------------- | -------------------------------------------------- | --------------------------- |
| Messaging Access Policy | `module.messaging.aws_iam_policy.messaging_access` | Policy ARN (dynamic lookup) |

---

## 🔍 Import Command Reference

### Manual Import (If needed locally)

```bash
cd config/terraform

# ECR
terraform import 'module.ecr["purchase-service"].aws_ecr_repository.this' purchase-service

# ALB (NEW!)
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-west-2 \
  --query "LoadBalancers[?LoadBalancerName=='ticketing-alb'].LoadBalancerArn" \
  --output text)
terraform import 'module.shared_alb.aws_lb.shared' "$ALB_ARN"

# Target Groups
TG_ARN=$(aws elbv2 describe-target-groups --region us-west-2 \
  --query "TargetGroups[?TargetGroupName=='purchase-service-tg'].TargetGroupArn" \
  --output text)
terraform import 'module.shared_alb.aws_lb_target_group.services["purchase-service"]' "$TG_ARN"

# Security Groups (NEW!)
ECS_SG=$(aws ec2 describe-security-groups --region us-west-2 \
  --filters "Name=group-name,Values=ticketing-ecs-sg" \
  --query "SecurityGroups[0].GroupId" --output text)
terraform import 'module.network.aws_security_group.this' "$ECS_SG"

# CloudWatch
terraform import 'module.logging["purchase-service"].aws_cloudwatch_log_group.this' /ecs/purchase-service

# Secrets
terraform import 'module.elasticache.aws_secretsmanager_secret.redis' ticketing-redis-credentials

# ElastiCache
terraform import 'module.elasticache.aws_elasticache_subnet_group.this' ticketing-cache-subnet-group

# RDS
terraform import 'module.rds.aws_db_subnet_group.default' ticketing-aurora-subnet-group

# IAM
POLICY_ARN=$(aws iam list-policies \
  --query "Policies[?PolicyName=='ticketing-message-messaging-access'].Arn" \
  --output text)
terraform import 'module.messaging.aws_iam_policy.messaging_access' "$POLICY_ARN"
```

---

## ✨ What Changed (Latest Update)

### Previously Missing (Now Added):

1. ✅ **Application Load Balancer** (`ticketing-alb`)

   - Was causing "ALB already exists" errors
   - Now automatically imported

2. ✅ **ECS Security Group** (`ticketing-ecs-sg`)

   - Was causing "Security group already exists" errors
   - Now automatically imported

3. ✅ **All Security Groups** (RDS, Redis)
   - Complete coverage of all network security groups
   - All automatically imported now

---

## 🎯 Complete Resource Count

| Category              | Count             |
| --------------------- | ----------------- |
| Container Registries  | 3                 |
| **Load Balancers**    | **1** ← NEW!      |
| Target Groups         | 3                 |
| **Security Groups**   | **4** ← COMPLETE! |
| Log Groups            | 3                 |
| Secrets               | 2                 |
| ElastiCache Resources | 2                 |
| RDS Resources         | 2                 |
| IAM Policies          | 1                 |
| **TOTAL**             | **21**            |

---

## 📝 Summary

**Your CI/CD now imports ALL 21 resource types automatically!**

- ✅ ECR Repositories
- ✅ Application Load Balancer (NEW!)
- ✅ Target Groups
- ✅ All Security Groups (NEW - Complete!)
- ✅ CloudWatch Log Groups
- ✅ Secrets Manager
- ✅ ElastiCache Resources
- ✅ RDS Resources
- ✅ IAM Policies

**Result:** Zero "already exists" errors! 🎉
