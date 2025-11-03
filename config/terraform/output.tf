output "ecs_cluster_names" {
  description = "Map of service identifiers to the created ECS cluster names."
  value       = { for service, _ in local.app_services : service => "${service}-cluster" }
}

output "ecs_service_names" {
  description = "Map of service identifiers to the ECS service names."
  value       = { for service, _ in local.app_services : service => service }
}

output "ecr_repository_urls" {
  description = "Map of service identifiers to their corresponding ECR repository URLs."
  value       = { for service, module_data in module.ecr : service => module_data.repository_url }
}

output "alb_dns_name" {
  description = "DNS name of the shared Application Load Balancer"
  value       = module.shared_alb.alb_dns_name
}

output "alb_endpoint" {
  description = "Complete endpoint information for the shared ALB"
  value = {
    dns_name = module.shared_alb.alb_dns_name
    services = {
      purchase_service = "http://${module.shared_alb.alb_dns_name}/purchase"
      query_service    = "http://${module.shared_alb.alb_dns_name}/query"
      mq_service       = "http://${module.shared_alb.alb_dns_name}/events"
    }
  }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for ticket events"
  value       = module.messaging.sns_topic_arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for ticket processing"
  value       = module.messaging.sqs_queue_url
}

output "rds_cluster_endpoint" {
  description = "RDS Aurora cluster endpoint (writer)"
  value       = module.rds.cluster_endpoint
}

output "rds_reader_endpoint" {
  description = "RDS Aurora reader endpoint"
  value       = module.rds.reader_endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = module.rds.secret_arn
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "Redis cluster port"
  value       = module.elasticache.redis_port
}

output "redis_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Redis password"
  value       = module.elasticache.redis_secret_arn
  sensitive   = true
}
