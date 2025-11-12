# ==============================================================================
# AURORA MYSQL (RDS) CONFIGURATION
# ==============================================================================

variable "rds_username" {
  description = "Master username for RDS database"
  type        = string
  default     = "admin"
}

variable "rds_instances" {
  description = "Total number of Aurora instances, 1 writer N readers"
  type        = number
  default     = 1
  validation {
    condition     = var.rds_instances >= 1 && var.rds_instances <= 15
    error_message = "RDS instances must be between 1 and 15."
  }
}

variable "rds_instance_class" {
  description = "Instance for Aurora"
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
  description = "Aurora MySQL engine version"
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
