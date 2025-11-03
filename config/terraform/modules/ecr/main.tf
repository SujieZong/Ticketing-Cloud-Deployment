# Create (or ensure) an ECR repo exists
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.repository_name
  }
}

# Force delete images when destroying ECR repository
resource "null_resource" "ecr_cleanup" {
  triggers = {
    repository_name = aws_ecr_repository.this.name
    region          = var.region
  }

  # This runs BEFORE terraform destroy to clean ECR images
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws ecr list-images \
        --repository-name ${self.triggers.repository_name} \
        --region ${self.triggers.region} \
        --query 'imageIds[*]' \
        --output json > /tmp/ecr-images.json 2>/dev/null || echo "[]" > /tmp/ecr-images.json
      
      if [ -s /tmp/ecr-images.json ] && [ "$(cat /tmp/ecr-images.json)" != "[]" ]; then
        aws ecr batch-delete-image \
          --repository-name ${self.triggers.repository_name} \
          --region ${self.triggers.region} \
          --image-ids file:///tmp/ecr-images.json || true
      fi
    EOT
  }
}
