#!/bin/bash
# Cleanup AWS resources that Terraform couldn't destroy due to missing state

set -e

REGION="us-west-2"
echo "🗑️  Cleaning up AWS resources in region: $REGION"

# Delete ECR repositories
echo "Deleting ECR repositories..."
aws ecr delete-repository --repository-name purchase-service --region $REGION --force 2>/dev/null || true
aws ecr delete-repository --repository-name query-service --region $REGION --force 2>/dev/null || true
aws ecr delete-repository --repository-name mq-projection-service --region $REGION --force 2>/dev/null || true

# Delete ECS services (must be done before cluster)
echo "Deleting ECS services..."

# Old cluster names (if they exist)
for service in ticketing-purchase-service ticketing-query-service ticketing-mq-projection-service; do
  aws ecs update-service --cluster ticketing-prod-cluster --service $service --desired-count 0 --region $REGION 2>/dev/null || true
done

sleep 10

for service in ticketing-purchase-service ticketing-query-service ticketing-mq-projection-service; do
  aws ecs delete-service --cluster ticketing-prod-cluster --service $service --region $REGION --force 2>/dev/null || true
done

# New cluster names (current config)
for cluster_service in "purchase-service-cluster:purchase-service" "query-service-cluster:query-service" "mq-projection-service-cluster:mq-projection-service"; do
  CLUSTER=$(echo $cluster_service | cut -d: -f1)
  SERVICE=$(echo $cluster_service | cut -d: -f2)
  
  echo "  Deleting service $SERVICE from cluster $CLUSTER..."
  aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 0 --region $REGION 2>/dev/null || true
  sleep 5
  aws ecs delete-service --cluster $CLUSTER --service $SERVICE --region $REGION --force 2>/dev/null || true
done

sleep 15

# Delete ECS clusters
echo "Deleting ECS clusters..."
aws ecs delete-cluster --cluster ticketing-prod-cluster --region $REGION 2>/dev/null || true
aws ecs delete-cluster --cluster purchase-service-cluster --region $REGION 2>/dev/null || true
aws ecs delete-cluster --cluster query-service-cluster --region $REGION 2>/dev/null || true
aws ecs delete-cluster --cluster mq-projection-service-cluster --region $REGION 2>/dev/null || true

# Delete ALB Target Groups
echo "Deleting ALB target groups..."
TARGET_GROUPS=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, '-service-tg')].TargetGroupArn" --output text 2>/dev/null || echo "")

if [ -n "$TARGET_GROUPS" ]; then
  for TG_ARN in $TARGET_GROUPS; do
    TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns $TG_ARN --region $REGION --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null || echo "")
    echo "  Deleting target group: $TG_NAME ($TG_ARN)"
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION 2>/dev/null || true
    sleep 2
  done
else
  echo "  No target groups found to delete"
fi

# Wait for target groups to be fully deleted
echo "Waiting for target groups to be fully deleted..."
for i in {1..30}; do
  REMAINING=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, '-service-tg')].TargetGroupName" --output text 2>/dev/null || echo "")
  if [ -z "$REMAINING" ]; then
    echo "✅ All target groups deleted"
    break
  fi
  echo "⏳ Still deleting target groups... ($i/30)"
  sleep 5
done

# Delete ALB
echo "Deleting Application Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, 'ticketing')].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_ARN" ]; then
  aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION 2>/dev/null || true
fi

# Delete CloudWatch Log Groups
echo "Deleting CloudWatch log groups..."
aws logs delete-log-group --log-group-name /ecs/purchase-service --region $REGION 2>/dev/null || true
aws logs delete-log-group --log-group-name /ecs/query-service --region $REGION 2>/dev/null || true
aws logs delete-log-group --log-group-name /ecs/mq-projection-service --region $REGION 2>/dev/null || true

# Delete Secrets Manager secrets
echo "Deleting Secrets Manager secrets..."
aws secretsmanager delete-secret --secret-id ticketing-redis-credentials --force-delete-without-recovery --region $REGION 2>/dev/null || true
aws secretsmanager delete-secret --secret-id ticketing-db-credentials --force-delete-without-recovery --region $REGION 2>/dev/null || true

# Delete RDS Cluster (if exists)
echo "Deleting RDS cluster..."
aws rds delete-db-cluster --db-cluster-identifier ticketing-aurora --skip-final-snapshot --region $REGION 2>/dev/null || true

# Delete RDS Subnet Group
echo "Deleting RDS subnet group..."
sleep 30  # Wait for cluster deletion to start
aws rds delete-db-subnet-group --db-subnet-group-name ticketing-aurora-subnet-group --region $REGION 2>/dev/null || true

# Wait for RDS subnet group to be fully deleted
echo "Waiting for RDS subnet group to be fully deleted..."
for i in {1..30}; do
  if ! aws rds describe-db-subnet-groups --db-subnet-group-name ticketing-aurora-subnet-group --region $REGION 2>/dev/null | grep -q "ticketing-aurora-subnet-group"; then
    echo "✅ RDS subnet group deleted"
    break
  fi
  echo "⏳ Still deleting... ($i/30)"
  sleep 10
done

# Delete RDS Parameter Group
echo "Deleting RDS parameter group..."
aws rds delete-db-cluster-parameter-group --db-cluster-parameter-group-name ticketing-mysql-params --region $REGION 2>/dev/null || true

# Wait for RDS parameter group to be fully deleted
echo "Waiting for RDS parameter group to be fully deleted..."
for i in {1..30}; do
  if ! aws rds describe-db-cluster-parameter-groups --db-cluster-parameter-group-name ticketing-mysql-params --region $REGION 2>/dev/null | grep -q "ticketing-mysql-params"; then
    echo "✅ RDS parameter group deleted"
    break
  fi
  echo "⏳ Still deleting... ($i/30)"
  sleep 10
done

# Delete ElastiCache cluster
echo "Deleting ElastiCache cluster..."
aws elasticache delete-cache-cluster --cache-cluster-id ticketing-redis --region $REGION 2>/dev/null || true

# Delete ElastiCache Subnet Group
echo "Deleting ElastiCache subnet group..."
sleep 30  # Wait for cluster deletion
aws elasticache delete-cache-subnet-group --cache-subnet-group-name ticketing-cache-subnet-group --region $REGION 2>/dev/null || true

# Wait for subnet group to be fully deleted
echo "Waiting for ElastiCache subnet group to be fully deleted..."
for i in {1..30}; do
  if ! aws elasticache describe-cache-subnet-groups --cache-subnet-group-name ticketing-cache-subnet-group --region $REGION 2>/dev/null | grep -q "ticketing-cache-subnet-group"; then
    echo "✅ ElastiCache subnet group deleted"
    break
  fi
  echo "⏳ Still deleting... ($i/30)"
  sleep 10
done

# Delete ElastiCache Parameter Group
echo "Deleting ElastiCache parameter group..."
aws elasticache delete-cache-parameter-group --cache-parameter-group-name ticketing-redis-params --region $REGION 2>/dev/null || true

# Wait for parameter group to be fully deleted
echo "Waiting for ElastiCache parameter group to be fully deleted..."
for i in {1..30}; do
  if ! aws elasticache describe-cache-parameter-groups --cache-parameter-group-name ticketing-redis-params --region $REGION 2>/dev/null | grep -q "ticketing-redis-params"; then
    echo "✅ ElastiCache parameter group deleted"
    break
  fi
  echo "⏳ Still deleting... ($i/30)"
  sleep 10
done

# Delete IAM Policy
echo "Deleting IAM policy..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='ticketing-message-messaging-access'].Arn" --output text 2>/dev/null || echo "")
if [ ! -z "$POLICY_ARN" ]; then
  aws iam delete-policy --policy-arn $POLICY_ARN 2>/dev/null || true
fi

# Delete Security Groups (must be done last after all resources are deleted)
echo "Waiting 60s for resources to fully delete before removing security groups..."
sleep 60

echo "Deleting security groups..."
for sg_name in ticketing-alb-sg ticketing-ecs-sg ticketing-rds-sg; do
  SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$sg_name" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION 2>/dev/null || true
  fi
done

# Wait for security groups to be fully deleted
echo "Waiting for security groups to be fully deleted..."
for i in {1..30}; do
  REMAINING_SGS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=ticketing-*" --query "SecurityGroups[].GroupName" --output text 2>/dev/null || echo "")
  if [ -z "$REMAINING_SGS" ]; then
    echo "✅ All security groups deleted"
    break
  fi
  echo "⏳ Still deleting security groups... ($i/30)"
  sleep 10
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Wait 2-3 more minutes before deploying!"
echo ""
echo "AWS uses eventual consistency - some resources may still"
echo "be processing deletions in the background even though the"
echo "delete commands succeeded."
echo ""
echo "Recommended: Wait 3 minutes, then run your deployment."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

