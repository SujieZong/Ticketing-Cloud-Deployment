# ==============================================================================
# COMPUTE (ECS) CONFIGURATION
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
    message-persistence-service = {
      repository_name = "message-persistence-service"
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
      min_capacity       = 1
      max_capacity       = 6
      cpu_target_value   = 60
      scale_in_cooldown  = 120
      scale_out_cooldown = 60
    }
    "query-service" = {
      min_capacity       = 1
      max_capacity       = 3
      cpu_target_value   = 70
      scale_in_cooldown  = 300
      scale_out_cooldown = 300
    }
    "message-persistence-service" = {
      min_capacity       = 1
      max_capacity       = 3
      cpu_target_value   = 70
      scale_in_cooldown  = 300
      scale_out_cooldown = 300
    }
  }
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
  description = "ALB path-based routing patterns for each service"
  type        = map(list(string))
  default = {
    "purchase-service"            = ["/purchase*"]
    "query-service"               = ["/query*"]
    "message-persistence-service" = ["/events*"]
  }
}

variable "service_http_methods" {
  description = "ALB HTTP method-based routing for each service (optional, used with path patterns)"
  type        = map(list(string))
  default     = {}
}
