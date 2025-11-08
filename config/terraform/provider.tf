# Specify where to find the AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.7.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.2"
    }
  }
}

# Configure AWS provider
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

# Configure Docker provider - uses local Docker daemon
provider "docker" {
  registry_auth {
    address  = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.token.password
  }
}

# Get ECR login token
data "aws_ecr_authorization_token" "token" {
  # 移除 depends_on，让 Terraform 自动处理依赖关系
}
