variable "service_name" {
  type        = string
  description = "Base name for ECS resources"
}

variable "service_type" {
  type        = string
  description = "Type of service: 'receiver' (HTTP only), 'processor' (SQS only), or 'combined' (both HTTP and SQS)"
  validation {
    condition     = contains(["receiver", "processor", "combined"], var.service_type)
    error_message = "Service type must be 'receiver', 'processor', or 'combined'."
  }
}

variable "image" {
  type        = string
  description = "ECR image URI (with tag)"
}

variable "container_port" {
  type        = number
  description = "Port your app listens on"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for FARGATE tasks"
}

variable "security_group_ids" {
  type        = list(string)
  description = "SGs for FARGATE tasks"
}

variable "execution_role_arn" {
  type        = string
  description = "ECS Task Execution Role ARN"
}

variable "task_role_arn" {
  type        = string
  description = "IAM Role ARN for app permissions"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name"
}

variable "ecs_count" {
  type        = number
  default     = 1
  description = "Desired Fargate task count"
}

variable "region" {
  type        = string
  description = "AWS region (for awslogs driver)"
}

variable "cpu" {
  type        = string
  default     = "256"
  description = "vCPU units"
}

variable "memory" {
  type        = string
  default     = "512"
  description = "Memory (MiB)"
}


# ALB Integration (only for receiver service)
variable "target_group_arn" {
  type        = string
  default     = null
  description = "ARN of the target group for ALB integration"
}

variable "alb_listener_arn" {
  type        = string
  default     = null
  description = "ARN of the ALB listener (for dependency)"
}

# Messaging Configuration (for processor service)
variable "sns_topic_arn" {
  type        = string
  default     = null
  description = "ARN of SNS topic for publishing events"
}

variable "sqs_queue_url" {
  type        = string
  default     = null
  description = "URL of SQS queue for consuming messages"
}

variable "sqs_queue_name" {
  type        = string
  default     = null
  description = "Name of SQS queue for consuming messages"
}

# Auto Scaling Configuration
variable "enable_autoscaling" {
  type        = bool
  default     = false
  description = "Enable auto scaling for ECS service"
}

variable "autoscaling_min_capacity" {
  type        = number
  default     = 2
  description = "Minimum number of tasks"
}

variable "autoscaling_max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of tasks"
}

variable "autoscaling_target_cpu" {
  type        = number
  default     = 70
  description = "Target CPU utilization percentage"
}

variable "autoscaling_scale_in_cooldown" {
  type        = number
  default     = 300
  description = "Scale-in cooldown in seconds"
}

variable "autoscaling_scale_out_cooldown" {
  type        = number
  default     = 300
  description = "Scale-out cooldown in seconds"
}

# Database Configuration
variable "db_endpoint" {
  type        = string
  description = "Database endpoint/host"
}

variable "db_port" {
  type        = number
  description = "Database port"
}

variable "db_username" {
  type        = string
  description = "Database username"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN that contains {username,password}"
  sensitive   = true
}

# Redis Configuration
variable "redis_endpoint" {
  type        = string
  description = "Redis endpoint/host"
}

variable "redis_port" {
  type        = number
  description = "Redis port"
}

variable "redis_secret_arn" {
  type        = string
  description = "Secrets Manager ARN that contains Redis password"
  sensitive   = true
  default     = null
}
