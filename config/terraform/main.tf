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

  # Dynamically construct IAM role ARNs if not provided
  execution_role_arn = var.execution_role_arn != "" ? var.execution_role_arn : "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  task_role_arn      = var.task_role_arn != "" ? var.task_role_arn : "arn:aws:iam::${var.aws_account_id}:role/LabRole"

  ecs_monitoring_services = {
    for service, _ in local.app_services : service => {
      cluster_name = "${service}-cluster"
      service_name = service
      min_capacity = local.ecs_autoscaling_configs[service].min_capacity
      cpu_threshold = try(var.ecs_cpu_warning_overrides[service], null)
    }
  }
}

# ==============================================================================
# Network Module - Shared VPC, Subnets, Security Groups for all services
# ==============================================================================
module "network" {
  source         = "./modules/network"
  service_name   = "ticketing" # Shared network for all services
  container_port = var.container_port
  alb_port       = var.alb_port
  rds_port       = var.rds_port
  redis_port     = var.elasticache_port
  cidr_blocks    = var.allowed_ingress_cidrs
}

# ==============================================================================
# ECR Module - Creates container repository for each service
# ==============================================================================
module "ecr" {
  for_each        = local.app_services
  source          = "./modules/ecr"
  repository_name = each.value.repository_name
  region          = var.aws_region
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
# Shared ALB Module - Single Application Load Balancer for all services
# ==============================================================================
module "shared_alb" {
  source            = "./modules/alb"
  project_name      = "ticketing"
  services          = local.app_services
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.alb_security_group_id
  health_check_path = "/health"
  service_health_check_paths = {
    "purchase-service"            = "/purchase/health"
    "query-service"               = "/query/health"
    "message-persistence-service" = "/events/health"
  }
  service_path_patterns = var.service_path_patterns
  service_http_methods  = var.service_http_methods
}

# ==============================================================================
# ECS Module - Cluster, task definition, and service (per service)
# ==============================================================================
module "ecs" {
  for_each           = var.create_ecs_services ? local.app_services : {}
  source             = "./modules/ecs"
  service_name       = each.key
  service_type       = "combined" # All services are combined (HTTP + messaging)
  image              = "${module.ecr[each.key].repository_url}:${each.value.image_tag}"
  container_port     = each.value.container_port
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.ecs_security_group_id]
  execution_role_arn = local.execution_role_arn
  task_role_arn      = local.task_role_arn
  log_group_name     = module.logging[each.key].log_group_name
  ecs_count          = each.value.desired_count
  region             = var.aws_region
  cpu                = each.value.cpu
  memory             = each.value.memory
  # Attach all services to their ALB target groups for health checks
  target_group_arn               = lookup(module.shared_alb.target_group_arns, each.key, null)
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
  db_endpoint   = module.rds.cluster_endpoint
  db_port       = 3306
  db_username   = var.rds_username
  db_password   = "" # Not used when db_secret_arn is provided
  db_secret_arn = module.rds.secret_arn

  # Redis configuration
  redis_endpoint   = module.elasticache.redis_endpoint
  redis_port       = module.elasticache.redis_port
  redis_secret_arn = module.elasticache.redis_secret_arn

  # Docker images should already exist in ECR before deployment
  # Use build-and-push.sh to build and push images first
  # Or use CI/CD pipeline to handle build and deployment
  depends_on = [module.ecr]
}
module "messaging" {
  source                     = "./modules/messaging"
  service_name               = "ticketing-message"
  sns_topic_name             = var.sns_topic_name
  sqs_queue_name             = var.sqs_queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  max_receive_count          = var.sqs_max_receive_count
  dlq_message_retention_seconds = var.sqs_dlq_message_retention_seconds
}

# ==============================================================================
# RDS Module - Aurora MySQL cluster with read replica
# ==============================================================================
module "rds" {
  source                 = "./modules/rds"
  name                   = "ticketing"
  username               = var.rds_username
  vpc_private_subnet_ids = module.network.subnet_ids
  rds_security_group_ids = [module.network.rds_security_group_id]
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
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.subnet_ids
  redis_security_group_id  = module.network.redis_security_group_id
  engine_version           = var.elasticache_engine_version
  node_type                = var.elasticache_node_type
  port                     = var.elasticache_port
  snapshot_retention_limit = var.elasticache_snapshot_retention_limit
  num_cache_nodes          = var.elasticache_num_nodes
}

module "monitoring" {
  count                          = var.enable_monitoring ? 1 : 0
  source                         = "./modules/monitoring"
  project_name                   = "ticketing"
  alb_arn                        = module.shared_alb.alb_arn
  target_group_arns              = module.shared_alb.target_group_arns
  sqs_queue_name                 = var.sqs_queue_name
  rds_cluster_id                 = module.rds.cluster_id
  redis_replication_group_id     = module.elasticache.redis_replication_group_id
  ecs_services                   = var.create_ecs_services ? local.ecs_monitoring_services : {}
  alb_unhealthy_threshold        = var.alb_unhealthy_threshold
  sqs_backlog_warning_threshold  = var.sqs_backlog_warning_threshold
  sqs_oldest_message_warning_seconds = var.sqs_oldest_message_warning_seconds
  rds_connection_warning_threshold   = var.rds_connection_warning_threshold
  redis_memory_warning_threshold = var.redis_memory_warning_threshold
  ecs_cpu_warning_threshold      = var.ecs_cpu_warning_threshold
}
