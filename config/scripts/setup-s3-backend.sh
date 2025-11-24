#!/bin/bash

##############################################################################
# Setup S3 Backend for Terraform State Management
# For AWS Learner Lab Environment
#
# This script creates an S3 bucket to store Terraform state files
# Run this BEFORE your first Terraform deployment
##############################################################################

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-west-2}"
BUCKET_PREFIX="ticketing-terraform-state"

echo "=========================================="
echo "🪣  S3 Backend Setup for Terraform State"
echo "=========================================="
echo ""

# Get AWS Account ID
echo "🔍 Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Error: Unable to get AWS Account ID"
    echo "   Make sure you have valid AWS credentials configured"
    exit 1
fi

echo "✅ AWS Account ID: $ACCOUNT_ID"
echo ""

# Construct bucket name
BUCKET_NAME="${BUCKET_PREFIX}-${ACCOUNT_ID}"

# Check if bucket already exists
echo "🔍 Checking if S3 bucket exists: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 bucket already exists: $BUCKET_NAME"
    echo ""
    echo "📋 Bucket Details:"
    aws s3api get-bucket-versioning --bucket "$BUCKET_NAME"
    echo ""
    echo "🎉 S3 backend is ready to use!"
    exit 0
fi

# Create S3 bucket
echo "📦 Creating S3 bucket: $BUCKET_NAME"
if [ "$AWS_REGION" = "us-east-1" ]; then
    # us-east-1 doesn't need LocationConstraint
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

echo "✅ Bucket created successfully"
echo ""

# Enable versioning
echo "🔄 Enabling versioning for state history..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo "✅ Versioning enabled"
echo ""

# Enable encryption
echo "🔒 Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "✅ Encryption enabled (AES256)"
echo ""

# Block public access (security best practice)
echo "🛡️  Configuring public access block..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✅ Public access blocked"
echo ""

# Verify bucket setup
echo "📋 Verifying bucket configuration..."
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Versioning:"
aws s3api get-bucket-versioning --bucket "$BUCKET_NAME"
echo ""

# Display Terraform backend configuration
echo "=========================================="
echo "✅ S3 Backend Setup Complete!"
echo "=========================================="
echo ""
echo "📝 Use this backend configuration in your Terraform:"
echo ""
cat <<TFBACKEND
terraform {
  backend "s3" {
    bucket  = "${BUCKET_NAME}"
    key     = "ticketing/terraform.tfstate"
    region  = "${AWS_REGION}"
    encrypt = true
  }
}
TFBACKEND
echo ""
echo "⚠️  Note: DynamoDB state locking is not available in AWS Learner Lab"
echo "    This means concurrent Terraform runs may conflict"
echo "    Always ensure only one deployment runs at a time"
echo ""
echo "🔍 To verify state files later:"
echo "   aws s3 ls s3://${BUCKET_NAME}/ticketing/"
echo ""
echo "📦 To list all state versions:"
echo "   aws s3api list-object-versions --bucket ${BUCKET_NAME} --prefix ticketing/"
echo ""
echo "🎉 You can now run your GitHub Actions workflow!"
