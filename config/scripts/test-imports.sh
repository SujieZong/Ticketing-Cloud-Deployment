#!/bin/bash
# Test import commands locally before CI/CD

REGION="us-west-2"
cd "$(dirname "$0")/../terraform"

echo "🧪 Testing import commands..."
echo ""

# Test Target Groups
echo "📦 Testing Target Group imports..."
TG_PURCHASE=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?TargetGroupName=='purchase-service-tg'].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ ! -z "$TG_PURCHASE" ]; then
  echo "  Found: purchase-service-tg"
  echo "  ARN: $TG_PURCHASE"
  echo "  Command: terraform import 'module.shared_alb.aws_lb_target_group.services[\"purchase-service\"]' \"$TG_PURCHASE\""
else
  echo "  ⚠️  purchase-service-tg not found"
fi

# Test Redis SG
echo ""
echo "🔒 Testing Redis Security Group import..."
REDIS_SG=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=ticketing-redis-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ ! -z "$REDIS_SG" ] && [ "$REDIS_SG" != "None" ]; then
  echo "  Found: ticketing-redis-sg"
  echo "  ID: $REDIS_SG"
  echo "  Command: terraform import 'module.elasticache.aws_security_group.redis_sg' \"$REDIS_SG\""
else
  echo "  ⚠️  ticketing-redis-sg not found"
fi

# Test RDS Cluster
echo ""
echo "🗄️  Testing RDS Cluster import..."
RDS_CLUSTER=$(aws rds describe-db-clusters --region $REGION --query "DBClusters[?DBClusterIdentifier=='ticketing-aurora'].DBClusterIdentifier" --output text 2>/dev/null || echo "")
if [ ! -z "$RDS_CLUSTER" ]; then
  echo "  Found: ticketing-aurora"
  echo "  Command: terraform import 'module.rds.aws_rds_cluster.this' 'ticketing-aurora'"
  
  # Check for instances
  INSTANCES=$(aws rds describe-db-instances --region $REGION --query "DBInstances[?DBClusterIdentifier=='ticketing-aurora'].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
  if [ ! -z "$INSTANCES" ]; then
    echo "  Found RDS instances: $INSTANCES"
    for instance in $INSTANCES; do
      echo "  Command: terraform import 'module.rds.aws_rds_cluster_instance.this[?]' '$instance'"
    done
  fi
else
  echo "  ⚠️  ticketing-aurora not found"
fi

# Test ALB
echo ""
echo "⚖️  Testing ALB import..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?LoadBalancerName=='ticketing-alb'].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_ARN" ]; then
  echo "  Found: ticketing-alb"
  echo "  ARN: $ALB_ARN"
  echo "  Command: terraform import 'module.shared_alb.aws_lb.shared' \"$ALB_ARN\""
else
  echo "  ⚠️  ticketing-alb not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test complete!"
echo ""
echo "If you see resources above, you can run the import commands locally:"
echo "  cd config/terraform"
echo "  # Copy the commands shown above"
echo ""
echo "Or just push and let CI/CD auto-import them!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
