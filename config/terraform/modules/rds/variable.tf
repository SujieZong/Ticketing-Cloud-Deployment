variable "name" {
  description = "Name prefix for RDS resources"
  type        = string
}

variable "username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "vpc_private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "rds_security_group_ids" {
  description = "List of security group IDs for RDS"
  type        = list(string)
}

variable "engine_version" {
  description = "Aurora MySQL engine version (8.0.mysql_aurora.3.05.2 is stable and widely available)"
  type        = string
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.t4g.medium"
}

variable "instances" {
  description = "Total number of instances (1 writer + N readers)"
  type        = number
  default     = 2
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "publicly_accessible" {
  description = "Whether the DB instances are publicly accessible"
  type        = bool
  default     = false
}

