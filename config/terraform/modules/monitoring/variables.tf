variable "project_name" {
  description = "Project name to prefix monitoring resources"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the shared Application Load Balancer"
  type        = string
}

variable "target_group_arns" {
  description = "Map of service target group ARNs"
  type        = map(string)
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue to monitor"
  type        = string
}

variable "rds_cluster_id" {
  description = "RDS cluster identifier"
  type        = string
}

variable "redis_replication_group_id" {
  description = "Replication group identifier for Redis"
  type        = string
}

variable "ecs_services" {
  description = "ECS services with metadata for alarms"
  type = map(object({
    cluster_name = string
    service_name = string
    min_capacity = number
    cpu_threshold = optional(number)
  }))
}

variable "alb_unhealthy_threshold" {
  description = "Number of unhealthy hosts that should trigger the ALB alarm"
  type        = number
}

variable "sqs_backlog_warning_threshold" {
  description = "Visible message count that triggers the backlog alarm"
  type        = number
}

variable "sqs_oldest_message_warning_seconds" {
  description = "Age in seconds that triggers the oldest-message alarm"
  type        = number
}

variable "rds_connection_warning_threshold" {
  description = "Connection count that signals RDS saturation"
  type        = number
}

variable "redis_memory_warning_threshold" {
  description = "Percent of Redis memory usage to warn on"
  type        = number
}

variable "ecs_cpu_warning_threshold" {
  description = "Default ECS CPU percentage warning threshold"
  type        = number
}
