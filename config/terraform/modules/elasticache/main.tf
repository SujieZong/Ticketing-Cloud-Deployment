# Single Redis instance for simplicity

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-cache-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "redis_sg" {
  name   = "${var.name}-redis-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.ecs_security_group_ids
    description     = "ECS tasks to Redis"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-redis-sg" }
}

resource "random_password" "auth" {
  length           = 32
  special          = true
  override_special = "!&#$^<>-"
}

# Store Redis password in Secrets Manager
resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.name}-redis-credentials"
  recovery_window_in_days = 0
  
  tags = {
    Name        = "${var.name}-redis-secret"
    Environment = "aws"
    Service     = var.name
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    password = random_password.auth.result
    endpoint = aws_elasticache_replication_group.this.primary_endpoint_address
    port     = var.port
  })
  
  depends_on = [aws_elasticache_replication_group.this]
}

# Create a custom parameter group for Redis
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-redis-params"
  family = "redis7"
}

# Redis Replication Group (supports AUTH token and high availability)
resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${var.name}-redis"
  description                = "Redis cluster for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  port                       = var.port
  parameter_group_name       = aws_elasticache_parameter_group.this.name
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  
  # Cluster configuration
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 1 ? true : false
  multi_az_enabled           = var.num_cache_nodes > 1 ? true : false
  
  # Security - TLS encryption and AUTH
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result
  auth_token_update_strategy = "ROTATE"
  
  # Maintenance and backups
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "sun:05:00-sun:07:00"
  auto_minor_version_upgrade = true
  
  # Lifecycle
  apply_immediately          = false
  
  tags = {
    Name        = "${var.name}-redis"
    Environment = "aws"
    Service     = var.name
  }
}