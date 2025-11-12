# ==============================================================================
# ELASTICACHE (REDIS) CONFIGURATION
# ==============================================================================

variable "elasticache_engine_version" {
  description = "Redis engine version for ElastiCache (e.g., 7.1, 7.0, 6.2)"
  type        = string
  default     = "7.1"
}

variable "elasticache_node_type" {
  description = "Node type for ElastiCache Redis instances (e.g., cache.t3.small)"
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
  default     = 0
  validation {
    condition     = var.elasticache_snapshot_retention_limit >= 0 && var.elasticache_snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days."
  }
}

variable "elasticache_num_nodes" {
  description = "Number of cache nodes in the Redis cluster"
  type        = number
  default     = 1
  validation {
    condition     = var.elasticache_num_nodes >= 1 && var.elasticache_num_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6."
  }
}
