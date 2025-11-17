# ==============================================================================
# MONITORING THRESHOLDS
# ==============================================================================

variable "enable_monitoring" {
  description = "Toggle to enable/disable CloudWatch alarm creation"
  type        = bool
  default     = true
}

variable "alb_unhealthy_threshold" {
  description = "Number of unhealthy targets that should trigger the ALB warning"
  type        = number
  default     = 1
}

variable "sqs_backlog_warning_threshold" {
  description = "Visible message count that should raise an SQS backlog warning"
  type        = number
  default     = 100
}

variable "sqs_oldest_message_warning_seconds" {
  description = "Age of the oldest SQS message before warning (seconds)"
  type        = number
  default     = 300
}

variable "rds_connection_warning_threshold" {
  description = "RDS connection count that should trigger a warning"
  type        = number
  default     = 60
}

variable "redis_memory_warning_threshold" {
  description = "Redis memory usage percentage that should trigger a warning"
  type        = number
  default     = 65
}

variable "ecs_cpu_warning_threshold" {
  description = "Default ECS CPU utilization percentage for warnings"
  type        = number
  default     = 75
}

variable "ecs_cpu_warning_overrides" {
  description = "Optional per-service overrides for ECS CPU warning thresholds"
  type        = map(number)
  default     = {}
}
