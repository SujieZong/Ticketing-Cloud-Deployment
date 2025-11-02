# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.service_name}-cluster"
}

# Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "${var.service_name}-container"
    image     = var.image
    essential = true

    portMappings = [{
      containerPort = var.container_port
    }]

    environment = [
      {
        name  = "SPRING_DATA_REDIS_HOST"
        value = var.redis_endpoint
      },
      {
        name  = "SPRING_DATA_REDIS_PORT"
        value = tostring(var.redis_port)
      },
      {
        name  = "DB_HOST"
        value = var.db_endpoint
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "SNS_TOPIC_ARN"
        value = var.sns_topic_arn
      },
      {
        name  = "TICKETS_BOOTSTRAP_VENUE_REDIS"
        value = "true"
      },
      {
        name  = "SQS_QUEUE_NAME"
        value = var.sqs_queue_name
      },
      {
        name  = "SQS_QUEUE_URL"
        value = var.sqs_queue_url
      },
      {
        name  = "AWS_REGION"
        value = var.region
      }
    ]

    secrets = concat([
      {
        name      = "DB_USER"
        valueFrom = "${var.db_secret_arn}:username::"
      },
      {
        name      = "DB_PASS"
        valueFrom = "${var.db_secret_arn}:password::"
      }
    ],
    var.redis_secret_arn != "" ? [
      {
        name      = "SPRING_DATA_REDIS_PASSWORD"
        valueFrom = "${var.redis_secret_arn}:password::"
      }
    ] : [])

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.ecs_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = true
  }


  # ALB integration for receiver and combined services
  dynamic "load_balancer" {
    for_each = (var.service_type == "receiver" || var.service_type == "combined") && var.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = "${var.service_name}-container"
      container_port   = var.container_port
    }
  }

  # Required for ALB integration
  health_check_grace_period_seconds = (var.service_type == "receiver" || var.service_type == "combined") && var.target_group_arn != "" ? 60 : null
}

# ==============================================================================
# Auto Scaling Configuration
# ==============================================================================

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU Based
resource "aws_appautoscaling_policy" "ecs_cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

