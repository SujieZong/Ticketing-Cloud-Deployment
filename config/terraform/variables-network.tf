# ==============================================================================
# NETWORKING & SECURITY CONFIGURATION
# ==============================================================================

variable "vpc_cidr" {
  description = "Network addressing for the default VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access the ALB (security group ingress)"
  type        = list(string)
  default     = ["209.121.228.207/32"]
}

variable "alb_port" {
  description = "Port for the Application Load Balancer to listen on"
  type        = number
  default     = 80
}

variable "container_port" {
  description = "Port for containers to listen on"
  type        = number
  default     = 8080
}

variable "rds_port" {
  description = "Port for the Aurora cluster"
  type        = number
  default     = 3306
}
