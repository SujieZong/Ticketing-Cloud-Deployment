variable "project_name" {
  description = "Project name for ALB resources"
  type        = string
}

variable "services" {
  description = "Map of services with their configurations"
  type = map(object({
    container_port  = number
    image_tag       = string
    repository_name = string
    cpu             = string
    memory          = string
    desired_count   = number
  }))
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "service_health_check_paths" {
  description = "Map of service names to their health check paths (overrides default)"
  type        = map(string)
  default     = {}
}

variable "service_path_patterns" {
  description = "Map of service names to their path patterns for ALB routing"
  type        = map(list(string))
  default     = {}
}

variable "service_http_methods" {
  description = "Map of service names to their HTTP methods for ALB routing (optional)"
  type        = map(list(string))
  default     = {}
}
