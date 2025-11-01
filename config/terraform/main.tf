# ==============================================================================
# Local configuration
# ==============================================================================
locals {
  base_app_services = var.app_services
  app_services = {
    for service, cfg in local.base_app_services :
    service => merge(cfg, {
      image_tag = lookup(var.service_image_tags, service, cfg.image_tag)
    })
  }
}

# ==============================================================================
# Network Module - VPC, Subnets, Security Groups (per service)
# ==============================================================================
module "network" {
  for_each       = local.app_services
  source         = "./modules/network"
  service_name   = each.key
  container_port = each.value.container_port
  cidr_blocks    = var.allowed_ingress_cidrs
}

# ==============================================================================
# ECR Module - Creates container repository for each service
# ==============================================================================
module "ecr" {
  for_each        = local.app_services
  source          = "./modules/ecr"
  repository_name = each.value.repository_name
}

# ==============================================================================
# Logging Module - CloudWatch Logs (per service)
# ==============================================================================
module "logging" {
  for_each          = local.app_services
  source            = "./modules/logging"
  service_name      = each.key
  retention_in_days = var.log_retention_days
}

# ==============================================================================
# ECS Module - Cluster, task definition, and service (per service)
# ==============================================================================
module "ecs" {
  for_each           = local.app_services
  source             = "./modules/ecs"
  service_name       = each.key
  image              = "${module.ecr[each.key].repository_url}:${each.value.image_tag}"
  container_port     = each.value.container_port
  subnet_ids         = module.network[each.key].subnet_ids
  security_group_ids = [module.network[each.key].security_group_id]
  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn
  log_group_name     = module.logging[each.key].log_group_name
  ecs_count          = each.value.desired_count
  region             = var.aws_region
  cpu                = each.value.cpu
  memory             = each.value.memory
}

# ==============================================================================
# Messaging Module - Shared SNS topic and SQS queue for ticket events
# ==============================================================================
module "messaging" {
  source         = "./modules/messaging"
  service_name   = "ticketing-message"
  sns_topic_name = var.sns_topic_name
  sqs_queue_name = var.sqs_queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
}
