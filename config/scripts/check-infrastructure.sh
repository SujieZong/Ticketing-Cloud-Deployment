#!/usr/bin/env bash
set -e

# ======= Configuration =======
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
TF_DIR="${TF_DIR:-$REPO_ROOT/config/terraform}"
AWS_REGION="${AWS_REGION:-us-west-2}"
TIME_WINDOW_MINUTES="${TIME_WINDOW_MINUTES:-60}"

# Calculate time window in milliseconds
TIME_WINDOW_MS=$((TIME_WINDOW_MINUTES * 60 * 1000))
START_TIME=$(($(date +%s) * 1000 - TIME_WINDOW_MS))

# ======= Colors =======
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ======= Helper Functions =======
print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${GREEN}✓ $1${NC}"
    echo "───────────────────────────────────────────"
}

print_metric() {
    echo -e "  ${YELLOW}$1:${NC} $2"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

# ======= Get Terraform Outputs =======
get_tf_output() {
    pushd "$TF_DIR" > /dev/null 2>&1
    terraform output -raw "$1" 2>/dev/null || echo ""
    popd > /dev/null 2>&1
}

# ======= Main Script =======
print_header "AWS Infrastructure Health Check"
echo -e "Region: ${BOLD}$AWS_REGION${NC}"
echo -e "Time Window: ${BOLD}Last $TIME_WINDOW_MINUTES minutes${NC}"
echo ""

# Get infrastructure endpoints
ALB_DNS=$(get_tf_output "alb_dns_name")
SQS_URL=$(get_tf_output "sqs_queue_url")
SNS_ARN=$(get_tf_output "sns_topic_arn")
RDS_ENDPOINT=$(get_tf_output "rds_cluster_endpoint")
REDIS_ENDPOINT=$(get_tf_output "redis_endpoint")

# ======= 1. ALB Health Check =======
print_section "1. Application Load Balancer (ALB)"
print_metric "DNS Name" "$ALB_DNS"

echo ""
echo "  Service Health Checks:"
for service in "purchase" "query" "events"; do
    health_path="/$service/health"
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}${health_path}" 2>/dev/null || echo "000")
    if [ "$response" = "200" ]; then
        echo -e "    ${GREEN}✓${NC} ${service} service: ${GREEN}Healthy${NC} (HTTP $response)"
    else
        echo -e "    ${RED}✗${NC} ${service} service: ${RED}Unhealthy${NC} (HTTP $response)"
    fi
done

# Check ALB target health
echo ""
echo "  Target Health:"
TARGET_GROUPS=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --output json 2>/dev/null | \
    jq -r '.TargetGroups[] | select(.TargetGroupName | contains("service")) | .TargetGroupArn')

for tg_arn in $TARGET_GROUPS; do
    tg_name=$(echo "$tg_arn" | awk -F':targetgroup/' '{print $2}' | cut -d'/' -f1)
    health_count=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --region "$AWS_REGION" 2>/dev/null | \
        jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    total_count=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --region "$AWS_REGION" 2>/dev/null | \
        jq '.TargetHealthDescriptions | length')
    
    if [ "$health_count" -gt 0 ]; then
        echo -e "    ${GREEN}✓${NC} $tg_name: $health_count/$total_count targets healthy"
    else
        echo -e "    ${RED}✗${NC} $tg_name: $health_count/$total_count targets healthy"
    fi
done

# ======= 2. RDS Database Check =======
print_section "2. RDS Aurora MySQL Database"
print_metric "Cluster Endpoint" "$RDS_ENDPOINT"

# Check database via Query Service
ticket_count=$(curl -s "http://${ALB_DNS}/query/api/v1/tickets" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
print_metric "Records in Database" "$ticket_count tickets"

# Check RDS cluster status
rds_status=$(aws rds describe-db-clusters --region "$AWS_REGION" 2>/dev/null | \
    jq -r '.DBClusters[] | select(.DatabaseName == "ticketing") | .Status' 2>/dev/null || echo "unknown")
print_metric "Cluster Status" "$rds_status"

# ======= 3. Redis ElastiCache Check =======
print_section "3. Redis (ElastiCache)"
print_metric "Primary Endpoint" "$REDIS_ENDPOINT"

# Check Redis operations from logs
redis_ops=$(aws logs filter-log-events \
    --log-group-name /ecs/purchase-service \
    --filter-pattern "Redis Connection" \
    --start-time "$START_TIME" \
    --region "$AWS_REGION" \
    --output json 2>/dev/null | jq '.events | length' 2>/dev/null || echo "0")
print_metric "Redis Operations (last ${TIME_WINDOW_MINUTES}m)" "$redis_ops"

# Check cache status
cache_status=$(aws elasticache describe-replication-groups --region "$AWS_REGION" 2>/dev/null | \
    jq -r '.ReplicationGroups[] | select(.ReplicationGroupId | contains("ticketing")) | .Status' 2>/dev/null || echo "unknown")
print_metric "Cache Status" "$cache_status"

# ======= 4. SNS Topic Check =======
print_section "4. SNS (Simple Notification Service)"
print_metric "Topic ARN" "$SNS_ARN"

# Count messages published to SNS
sns_published=$(aws logs filter-log-events \
    --log-group-name /ecs/purchase-service \
    --filter-pattern "Message published to SNS" \
    --start-time "$START_TIME" \
    --region "$AWS_REGION" \
    --output json 2>/dev/null | jq '.events | length' 2>/dev/null || echo "0")
print_metric "Messages Published (last ${TIME_WINDOW_MINUTES}m)" "$sns_published"

# Get SNS topic attributes
subscriptions=$(aws sns get-topic-attributes \
    --topic-arn "$SNS_ARN" \
    --region "$AWS_REGION" \
    --output json 2>/dev/null | jq -r '.Attributes.SubscriptionsConfirmed' 2>/dev/null || echo "0")
print_metric "Active Subscriptions" "$subscriptions"

# ======= 5. SQS Queue Check =======
print_section "5. SQS (Simple Queue Service)"
print_metric "Queue URL" "$SQS_URL"

# Get queue attributes
queue_attrs=$(aws sqs get-queue-attributes \
    --queue-url "$SQS_URL" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
    --region "$AWS_REGION" \
    --output json 2>/dev/null)

messages_available=$(echo "$queue_attrs" | jq -r '.Attributes.ApproximateNumberOfMessages' 2>/dev/null || echo "0")
messages_in_flight=$(echo "$queue_attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible' 2>/dev/null || echo "0")
messages_delayed=$(echo "$queue_attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesDelayed' 2>/dev/null || echo "0")

print_metric "Messages Available" "$messages_available"
print_metric "Messages In Flight" "$messages_in_flight"
print_metric "Messages Delayed" "$messages_delayed"

# Count messages received by consumer
sqs_received=$(aws logs filter-log-events \
    --log-group-name /ecs/mq-projection-service \
    --filter-pattern "Received ticketId" \
    --start-time "$START_TIME" \
    --region "$AWS_REGION" \
    --output json 2>/dev/null | jq '.events | length' 2>/dev/null || echo "0")
print_metric "Messages Consumed (last ${TIME_WINDOW_MINUTES}m)" "$sqs_received"

# ======= Summary =======
print_header "Summary"

echo -e "Message Flow (last ${TIME_WINDOW_MINUTES} minutes):"
echo -e "  ${BOLD}Purchase Service${NC} → ${BOLD}SNS${NC} → ${BOLD}SQS${NC} → ${BOLD}MQ Consumer${NC} → ${BOLD}RDS${NC}"
echo ""
echo -e "  1. SNS Messages Published:  ${YELLOW}$sns_published${NC}"
echo -e "  2. SQS Messages Consumed:   ${YELLOW}$sqs_received${NC}"
echo -e "  3. Tickets in Database:     ${YELLOW}$ticket_count${NC}"
echo ""

if [ "$sns_published" -eq "$sqs_received" ] && [ "$sqs_received" -eq "$ticket_count" ]; then
    echo -e "${GREEN}✓ Message flow is working correctly!${NC}"
    echo -e "${GREEN}  All messages were successfully processed end-to-end.${NC}"
else
    echo -e "${YELLOW}⚠ Message counts may differ (this is normal if messages are still processing)${NC}"
fi

echo ""
print_header "Check Complete"
