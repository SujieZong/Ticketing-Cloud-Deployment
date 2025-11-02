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

output "alb_dns_names" {
  description = "Map of service identifiers to their ALB DNS names."
  value       = { for service, module_data in module.alb : service => module_data.alb_dns_name }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for ticket events"
  value       = module.messaging.sns_topic_arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for ticket processing"
  value       = module.messaging.sqs_queue_url
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.elasticache.redis_endpoint
}

output "redis_port" {
  description = "Redis cluster port"
  value       = module.elasticache.redis_port
}
