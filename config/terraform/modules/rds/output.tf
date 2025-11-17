output "cluster_endpoint" {
  description = "The cluster endpoint for write operations"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "The reader endpoint for read-only operations"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "database_name" {
  description = "The name of the database"
  value       = aws_rds_cluster.this.database_name
}

output "secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db.arn
  sensitive   = true
}

output "cluster_id" {
  description = "Identifier of the RDS cluster (used for monitoring)"
  value       = aws_rds_cluster.this.id
}
