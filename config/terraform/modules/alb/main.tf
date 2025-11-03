# ==============================================================================
# Shared Application Load Balancer for all services
# ==============================================================================

# Locals for stable priority calculation
locals {
  http_service_keys       = sort(keys(var.services))
  http_service_priorities = { for idx, k in local.http_service_keys : k => 100 + idx }
}

# Application Load Balancer
resource "aws_lb" "shared" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for each service
resource "aws_lb_target_group" "services" {
  for_each = var.services

  name        = "${each.key}-tg"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    path                = lookup(var.service_health_check_paths, each.key, var.health_check_path)
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${each.key}-tg"
  }
}

# ALB Listener (HTTP on port 80) with path-based routing
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 80
  protocol          = "HTTP"

  # Default action - return 404 for unknown paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "The requested path does not exist"
        available_services = [
          "/purchase",
          "/query",
          "/events"
        ]
      })
      status_code = "404"
    }
  }
}

# Listener Rules for path-based routing
resource "aws_lb_listener_rule" "services" {
  for_each = var.services

  listener_arn = aws_lb_listener.http.arn
  priority     = 100 + index(keys(var.services), each.key) * 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = lookup(var.service_path_patterns, each.key, ["/${each.key}*"])
    }
  }

  # Optional: HTTP method matching
  dynamic "condition" {
    for_each = lookup(var.service_http_methods, each.key, null) != null ? [1] : []
    content {
      http_request_method {
        values = var.service_http_methods[each.key]
      }
    }
  }
}
