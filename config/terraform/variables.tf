# ==============================================================================
# AWS CREDENTIALS & REGION CONFIGURATION
# ==============================================================================

variable "aws_access_key_id" {
  type      = string
  default   = ""
  sensitive = true
  description = "AWS access key ID for authentication"
}

variable "aws_secret_access_key" {
  type      = string
  default   = ""
  sensitive = true
  description = "AWS secret access key for authentication"
}

variable "aws_session_token" {
  type      = string
  default   = ""
  sensitive = true
  description = "AWS session token for temporary credentials"
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region where resources will be deployed"
}

# ==============================================================================
# IAM ROLES & PERMISSIONS
# ==============================================================================

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN used by ECS tasks to pull images and publish logs"
  default     = "arn:aws:iam::589535382240:role/LabRole"
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN assumed by the running task for application permissions"
  default     = "arn:aws:iam::589535382240:role/LabRole"
}

# ==============================================================================
# LOGGING CONFIGURATION
# ==============================================================================

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain CloudWatch logs"
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
  default     = 345600  # 4 days
}

variable "sqs_receive_wait_time_seconds" {
  description = "Long polling wait time for the ticket processing SQS queue"
  type        = number
  default     = 20
}

# ==============================================================================
# NETWORKING & SECURITY
# ==============================================================================

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access the services (security group ingress)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ==============================================================================
# APPLICATION SERVICES CONFIGURATION
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

variable "service_image_tags" {
  description = "Override map for image tags (e.g., set via CI to the latest Git SHA)"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# AUTO SCALING OVERRIDES
# ==============================================================================

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
