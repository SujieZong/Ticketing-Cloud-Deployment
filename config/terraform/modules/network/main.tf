# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# List all subnets in that VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ====== ALB Security Group =====
resource "aws_security_group" "alb_sg" {
  name   = "${var.service_name}-alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = var.alb_port
    to_port     = var.alb_port
    protocol    = "tcp"
    cidr_blocks = length(var.cidr_blocks) > 0 ? var.cidr_blocks : ["0.0.0.0/0"]
    description = "Allow public traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.service_name}-alb-sg"
  }
}



# ====== ECS Security Group =====
# Create Security Group for ECS Tasks

resource "aws_security_group" "this" {
  name        = "${var.service_name}-ecs-sg"
  description = "Allow inbound traffic on ${var.container_port}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Update to access from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.service_name}-ecs-sg"
  }
}


# ====== RDS Security Group =====
resource "aws_security_group" "rds_sg" {
  name   = "${var.service_name}-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.this.id]
    description     = "RDS only allow access from ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.service_name}-rds-sg"
  }
}


