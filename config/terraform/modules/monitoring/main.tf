locals {
  # Extract the part after the account id in ALB ARN (e.g. loadbalancer/app/..)
  load_balancer_dimension = length(split(":", var.alb_arn)) > 5 ? element(split(":", var.alb_arn), 5) : var.alb_arn
  target_group_dimensions = {
    for name, arn in var.target_group_arns :
    # use the ARN suffix (index 5) rather than regexreplace for portability
    name => length(split(":", arn)) > 5 ? element(split(":", arn), 5) : arn
  }
}

resource "aws_sns_topic" "warning" {
  name = "${var.project_name}-monitoring-warning"

  tags = {
    Service = "monitoring"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  for_each            = local.target_group_dimensions
  alarm_name          = "${var.project_name}-${each.key}-alb-unhealthy"
  alarm_description   = "${each.key} target group has unhealthy hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alb_unhealthy_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    LoadBalancer = local.load_balancer_dimension
    TargetGroup  = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_backlog" {
  alarm_name          = "${var.project_name}-sqs-visible-warning"
  alarm_description   = "SQS queue depth is growing"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = 120
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.sqs_backlog_warning_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_oldest" {
  alarm_name          = "${var.project_name}-sqs-oldest-message"
  alarm_description   = "Oldest SQS message is waiting too long"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.sqs_oldest_message_warning_seconds
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-rds-connections"
  alarm_description   = "RDS connections nearing max"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 120
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.rds_connection_warning_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-redis-memory"
  alarm_description   = "Redis memory usage is high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.redis_memory_warning_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    ReplicationGroupId = var.redis_replication_group_id
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each            = var.ecs_services
  alarm_name          = "${var.project_name}-${each.key}-cpu"
  alarm_description   = "${each.key} CPU is saturated"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = coalesce(each.value.cpu_threshold, var.ecs_cpu_warning_threshold)
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_capacity" {
  for_each            = var.ecs_services
  alarm_name          = "${var.project_name}-${each.key}-task-count"
  alarm_description   = "${each.key} running tasks fell below minimum"
  namespace           = "AWS/ECS"
  metric_name         = "RunningTaskCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = each.value.min_capacity
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.warning.arn]

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }
}
