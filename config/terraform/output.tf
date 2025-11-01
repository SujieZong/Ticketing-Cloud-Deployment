output "ecs_cluster_names" {
  description = "Map of service identifiers to the created ECS cluster names."
  value       = { for service, module_data in module.ecs : service => module_data.cluster_name }
}

output "ecs_service_names" {
  description = "Map of service identifiers to the ECS service names."
  value       = { for service, module_data in module.ecs : service => module_data.service_name }
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
