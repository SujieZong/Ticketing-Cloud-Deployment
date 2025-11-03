# ==============================================================================
# AWS PROVIDER CONFIGURATION
# ==============================================================================

variable "aws_access_key_id" {
  type        = string
  default     = null
  sensitive   = true
  description = "AWS access key ID for authentication"
}

variable "aws_secret_access_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "AWS secret access key for authentication"
}

variable "aws_session_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "AWS session token for temporary credentials"
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region where resources will be deployed"
}

variable "aws_account_id" {
  type        = string
  default     = "339712827106"
  description = "AWS account ID for ECR and other resources"
}

# ==============================================================================
# NETWORKING & SECURITY CONFIGURATION
# ==============================================================================

variable "vpc_cidr" {
  description = "Network Addressing for default vpc"
  type        = string
  default     = "172.31.0.0/16" # Default VPC CIDR
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access the ALB (security group ingress)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_port" {
  description = "Port for ALB to listen on"
  type        = number
  default     = 80
}

variable "container_port" {
  description = "Port for containers to listen on"
  type        = number
  default     = 8080
}

variable "rds_port" {
  description = "Port for RDS database"
  type        = number
  default     = 3306
}

# ==============================================================================
# IAM ROLES & PERMISSIONS
# ==============================================================================

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN used by ECS tasks to pull images and publish logs (硬编码为当前账户)"
  default     = "arn:aws:iam::339712827106:role/LabRole"
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN assumed by the running task for application permissions (硬编码为当前账户)"
  default     = "arn:aws:iam::339712827106:role/LabRole"
}

# ==============================================================================
# COMPUTE RESOURCES (ECS) CONFIGURATION
# ==============================================================================

variable "app_services" {
  description = "Map of application services to deploy via ECS"
  type = map(object({
    repository_name = string
    container_port  = number
    cpu             = string
    memory          = string
    desired_count   = number
    image_tag       = string
  }))

  default = {
    purchase-service = {
      repository_name = "purchase-service"
      container_port  = 8080
      cpu             = "1024"
      memory          = "2048"
      desired_count   = 1
      image_tag       = "latest"
    }
    query-service = {
      repository_name = "query-service"
      container_port  = 8080
      cpu             = "1024"
      memory          = "2048"
      desired_count   = 1
      image_tag       = "latest"
    }
    mq-projection-service = {
      repository_name = "mq-projection-service"
      container_port  = 8080
      cpu             = "512"
      memory          = "1024"
      desired_count   = 1
      image_tag       = "latest"
    }
  }
}

variable "ecs_autoscaling_overrides" {
  description = "Override auto scaling settings per service"
  type = map(object({
    min_capacity       = optional(number, 1)
    max_capacity       = optional(number, 3)
    cpu_target_value   = optional(number, 70)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 300)
  }))
  default = {
    "purchase-service" = {
      min_capacity       = 3
      max_capacity       = 6
      cpu_target_value   = 60
      scale_in_cooldown  = 120
      scale_out_cooldown = 60
    }
  }
}

# ==============================================================================
# MESSAGING SERVICES (SNS/SQS) CONFIGURATION
# ==============================================================================

variable "sns_topic_name" {
  description = "Name of the SNS topic used for ticket events"
  type        = string
  default     = "ticket-events"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue subscribed to the ticket topic"
  type        = string
  default     = "ticket-sql"
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for the ticket processing SQS queue"
  type        = number
  default     = 30
}

variable "sqs_message_retention_seconds" {
  description = "Message retention period for the ticket processing SQS queue"
  type        = number
  default     = 345600 # 4 days
}

variable "sqs_receive_wait_time_seconds" {
  description = "Long polling wait time for the ticket processing SQS queue"
  type        = number
  default     = 20
}

# ==============================================================================
# RDS DATABASE CONFIGURATION
# ==============================================================================

variable "rds_username" {
  description = "Master username for RDS database"
  type        = string
  default     = "admin"
}

variable "rds_instances" {
  description = "Total number of Aurora instances (1 writer + N readers). Set to 1 for single instance, 2 for 1 writer + 1 reader, etc."
  type        = number
  default     = 2
  validation {
    condition     = var.rds_instances >= 1 && var.rds_instances <= 15
    error_message = "RDS instances must be between 1 and 15."
  }
}

variable "rds_instance_class" {
  description = "Instance class for Aurora instances (e.g., db.t4g.medium, db.r6g.large)"
  type        = string
  default     = "db.t4g.medium"
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain RDS backups (1-35 days)"
  type        = number
  default     = 7
  validation {
    condition     = var.rds_backup_retention_days >= 1 && var.rds_backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

variable "rds_engine_version" {
  description = "Aurora MySQL engine version (hardcoded to stable version 8.0.mysql_aurora.3.05.2)"
  type        = string
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "rds_publicly_accessible" {
  description = "Whether the DB instances are publicly accessible (should be false for production)"
  type        = bool
  default     = false
}

variable "rds_database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "ticketing"
}

# ==============================================================================
# ELASTICACHE REDIS CONFIGURATION
# ==============================================================================

variable "elasticache_engine_version" {
  description = "Redis engine version for ElastiCache (e.g., 7.1, 7.0, 6.2)"
  type        = string
  default     = "7.1"
}

variable "elasticache_node_type" {
  description = "Node type for ElastiCache Redis instances (e.g., cache.t3.small, cache.r6g.large)"
  type        = string
  default     = "cache.t3.small"
}

variable "elasticache_port" {
  description = "Port for ElastiCache Redis"
  type        = number
  default     = 6379
}

variable "elasticache_snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots (0 to disable)"
  type        = number
  default     = 1
  validation {
    condition     = var.elasticache_snapshot_retention_limit >= 0 && var.elasticache_snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days."
  }
}

variable "elasticache_num_nodes" {
  description = "Number of cache nodes in the Redis cluster. Set to 1 for single node (dev/test), 2+ for high availability (production)"
  type        = number
  default     = 1
  validation {
    condition     = var.elasticache_num_nodes >= 1 && var.elasticache_num_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6."
  }
}

# ==============================================================================
# MONITORING & LOGGING CONFIGURATION
# ==============================================================================

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain CloudWatch logs"
}

# ==============================================================================
# APPLICATION-SPECIFIC OVERRIDES
# ==============================================================================

variable "service_image_tags" {
  description = "Override map for image tags (e.g., set via CI to the latest Git SHA)"
  type        = map(string)
  default     = {}
}

variable "service_path_patterns" {
  description = "ALB path-based routing patterns for each service. Customize the URL paths that route to each service."
  type        = map(list(string))
  default = {
    "purchase-service"      = ["/purchase*"]
    "query-service"         = ["/query*"]
    "mq-projection-service" = ["/events*"]
  }
}

variable "service_http_methods" {
  description = "ALB HTTP method-based routing for each service (optional, used with path patterns)"
  type        = map(list(string))
  default     = {}
}