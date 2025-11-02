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

  # Auto scaling configuration with overrides
  ecs_autoscaling_configs = {
    for service, _ in local.app_services : service => {
      min_capacity       = try(var.ecs_autoscaling_overrides[service].min_capacity, 1)
      max_capacity       = try(var.ecs_autoscaling_overrides[service].max_capacity, 3)
      cpu_target_value   = try(var.ecs_autoscaling_overrides[service].cpu_target_value, 70)
      scale_in_cooldown  = try(var.ecs_autoscaling_overrides[service].scale_in_cooldown, 300)
      scale_out_cooldown = try(var.ecs_autoscaling_overrides[service].scale_out_cooldown, 300)
    }
  }
}

# ==============================================================================
# Network Module - VPC, Subnets, Security Groups (per service)
# ==============================================================================
module "network" {
  for_each       = local.app_services
  source         = "./modules/network"
  service_name   = each.key
  container_port = var.container_port
  alb_port       = var.alb_port
  rds_port       = var.rds_port
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
# Docker Build & Push - Build locally and push to ECR
# ==============================================================================
locals {
  service_directory_map = {
    "purchase-service"      = "PurchaseService"
    "query-service"         = "QueryService"
    "mq-projection-service" = "RabbitCombinedConsumer"
  }
}

resource "docker_image" "app" {
  for_each = local.app_services

  name = "${module.ecr[each.key].repository_url}:${each.value.image_tag}"

  build {
    context    = "${path.root}/../../${local.service_directory_map[each.key]}"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"  
  }

  depends_on = [module.ecr]
}

resource "docker_registry_image" "app" {
  for_each = local.app_services

  name = docker_image.app[each.key].name

  depends_on = [docker_image.app]
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
# ALB Module - Application Load Balancer (per service)
# ==============================================================================
module "alb" {
  for_each          = local.app_services
  source            = "./modules/alb"
  service_name      = each.key
  vpc_id            = module.network[each.key].vpc_id
  subnet_ids        = module.network[each.key].subnet_ids
  security_group_id = module.network[each.key].alb_security_group_id
  container_port    = each.value.container_port
  health_check_path = "/health"
}

# ==============================================================================
# ECS Module - Cluster, task definition, and service (per service)
# ==============================================================================
module "ecs" {
  for_each                       = local.app_services
  source                         = "./modules/ecs"
  service_name                   = each.key
  service_type                   = "combined" # All services are combined (HTTP + messaging)
  image                          = "${module.ecr[each.key].repository_url}:${each.value.image_tag}"
  container_port                 = each.value.container_port
  subnet_ids                     = module.network[each.key].subnet_ids
  security_group_ids             = [module.network[each.key].ecs_security_group_id]
  execution_role_arn             = var.execution_role_arn
  task_role_arn                  = var.task_role_arn
  log_group_name                 = module.logging[each.key].log_group_name
  ecs_count                      = each.value.desired_count
  region                         = var.aws_region
  cpu                            = each.value.cpu
  memory                         = each.value.memory
  target_group_arn               = module.alb[each.key].target_group_arn
  sns_topic_arn                  = module.messaging.sns_topic_arn
  sqs_queue_name                 = var.sqs_queue_name
  sqs_queue_url                  = module.messaging.sqs_queue_url
  enable_autoscaling             = true
  autoscaling_min_capacity       = local.ecs_autoscaling_configs[each.key].min_capacity
  autoscaling_max_capacity       = local.ecs_autoscaling_configs[each.key].max_capacity
  autoscaling_target_cpu         = local.ecs_autoscaling_configs[each.key].cpu_target_value
  autoscaling_scale_in_cooldown  = local.ecs_autoscaling_configs[each.key].scale_in_cooldown
  autoscaling_scale_out_cooldown = local.ecs_autoscaling_configs[each.key].scale_out_cooldown

  # Database configuration
  db_endpoint  = module.rds.cluster_endpoint
  db_port      = 3306
  db_username  = var.rds_username
  db_password  = ""  # Not used when db_secret_arn is provided
  db_secret_arn = module.rds.secret_arn

  # Redis configuration
  redis_endpoint = module.elasticache.redis_endpoint
  redis_port     = module.elasticache.redis_port
  redis_secret_arn = module.elasticache.redis_secret_arn

  # Ensure Docker images are pushed before creating ECS tasks
  depends_on = [docker_registry_image.app]
}
module "messaging" {
  source                     = "./modules/messaging"
  service_name               = "ticketing-message"
  sns_topic_name             = var.sns_topic_name
  sqs_queue_name             = var.sqs_queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
}

# ==============================================================================
# RDS Module - Aurora MySQL cluster with read replica
# ==============================================================================
module "rds" {
  source                 = "./modules/rds"
  name                   = "ticketing"
  username               = var.rds_username
  vpc_private_subnet_ids = module.network["purchase-service"].subnet_ids
  rds_security_group_ids = [module.network["purchase-service"].rds_security_group_id]
  instances              = var.rds_instances
  instance_class         = var.rds_instance_class
  backup_retention_days  = var.rds_backup_retention_days
  engine_version         = var.rds_engine_version
  publicly_accessible    = var.rds_publicly_accessible
}

# ==============================================================================
# Elasticache Module - Redis cluster for caching
# ==============================================================================
module "elasticache" {
  source                   = "./modules/elasticache"
  name                     = "ticketing"
  vpc_id                   = module.network["purchase-service"].vpc_id
  subnet_ids               = module.network["purchase-service"].subnet_ids
  ecs_security_group_ids   = [module.network["purchase-service"].ecs_security_group_id]
  engine_version           = var.elasticache_engine_version
  node_type                = var.elasticache_node_type
  port                     = var.elasticache_port
  snapshot_retention_limit = var.elasticache_snapshot_retention_limit
  num_cache_nodes          = var.elasticache_num_nodes
}