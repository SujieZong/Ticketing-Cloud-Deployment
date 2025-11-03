variable "repository_name" {
  description = "The name of the ECR repository"
  type        = string
}

variable "region" {
  description = "AWS region for ECR cleanup"
  type        = string
  default     = "us-west-2"
}
