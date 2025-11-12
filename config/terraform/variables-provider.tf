# ==============================================================================
# AWS PROVIDER & GLOBAL SETTINGS
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
# IAM ROLES & PERMISSIONS
# ==============================================================================

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN used by ECS tasks to pull images and publish logs"
  default     = ""
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN assumed by the running task for application permissions"
  default     = ""
}

# ==============================================================================
# MONITORING & LOGGING
# ==============================================================================

variable "log_retention_days" {
  type        = number
  default     = 3
  description = "Number of days to retain CloudWatch logs"
}
