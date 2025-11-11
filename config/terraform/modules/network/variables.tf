variable "service_name" {
  description = "Base name for SG"
  type        = string
}
variable "container_port" {
  description = "Port to expose for ecs"
  type        = number
}
variable "alb_port" {
  description = "Port to expose for alb"
  type        = number
}
variable "rds_port" {
  description = "Port to expose for rds"
  type        = number
}
variable "redis_port" {
  description = "Port to expose for redis"
  type        = number
  default     = 6379
}
variable "cidr_blocks" {
  description = "Which CIDRs can reach the service"
  type        = list(string)
  default     = []
}
