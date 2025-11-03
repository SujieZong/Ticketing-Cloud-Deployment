# Aurora MySQL Cluster with 1 writer and 1 reader instance

data "aws_rds_engine_version" "aurora_mysql" {
  engine       = "aurora-mysql"
  version      = "8.0"
  default_only = true
}

resource "aws_db_subnet_group" "default" {
  name       = "${var.name}-aurora-subnet-group"
  subnet_ids = var.vpc_private_subnet_ids
  tags = {
    Name = "${var.name}-aurora-subnet-group"
  }
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}-db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.db.result
  })
}

resource "aws_rds_cluster_parameter_group" "this" {
  name   = "${var.name}-mysql-params"
  family = "aurora-mysql8.0"
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name}-aurora"
  engine             = "aurora-mysql"
  engine_version     = data.aws_rds_engine_version.aurora_mysql.version
  master_username    = var.username
  master_password    = random_password.db.result
  database_name      = "ticketing"

  db_subnet_group_name            = aws_db_subnet_group.default.name
  vpc_security_group_ids          = var.rds_security_group_ids
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  backup_retention_period = var.backup_retention_days
  deletion_protection     = false
  skip_final_snapshot     = true
  storage_encrypted       = true

  tags = {
    Name        = "${var.name}-aurora-cluster"
    Environment = "aws"
    Service     = var.name
  }
}

# Writer instance (automatically created by Aurora, but we define it explicitly)
resource "aws_rds_cluster_instance" "writer" {
  identifier          = "${var.name}-aurora-writer"
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = var.instance_class
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = var.publicly_accessible

  tags = {
    Name        = "${var.name}-aurora-writer"
    Environment = "aws"
    Service     = var.name
    Type        = "writer"
  }
}

# Reader instance for read-only operations
resource "aws_rds_cluster_instance" "readers" {
  count               = var.instances - 1 # Subtract 1 because writer is already created
  identifier          = "${var.name}-aurora-reader-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = var.instance_class
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = var.publicly_accessible
  apply_immediately   = true

  tags = {
    Name        = "${var.name}-aurora-reader"
    Environment = "aws"
    Service     = var.name
    Type        = "reader"
  }
}