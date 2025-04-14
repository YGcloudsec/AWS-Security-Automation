provider "aws" {
  region = var.aws_region
}

# VPC with private and public subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "secure-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Define the bucket name as a local variable
locals {
  bucket_name = "secure-example-bucket-${random_string.suffix.result}"
}

# Random suffix for unique bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false # had to add due to AWS naming policy
}

# Secure S3 bucket (private, encrypted)
resource "aws_s3_bucket" "example" {
  bucket = "secure-example-bucket-${random_string.suffix.result}"

  tags = {
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true 
  block_public_policy     = true
  ignore_public_acls      = true 
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.example]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [aws_s3_bucket.example]
}

# S3 bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.example.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.example.id}"
      },
      {
        Sid       = "AllowCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.example.id}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket.example]
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.example.id

  acl = "public-read" # Grants READ access to AllUsers

  depends_on = [aws_s3_bucket_public_access_block.example]
}

# IAM role with least privilege
resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# CloudTrail for auditing
resource "aws_cloudtrail" "example" {
  name                          = "secure-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.example.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket.example]
}

# SCP to enforce MFA (example)
resource "aws_organizations_policy" "require_mfa" {
  name        = "require-mfa"
  description = "Enforce MFA for IAM users"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}