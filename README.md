 
# AWS Security Automation Pipeline

A project to deploy secure AWS infrastructure with Terraform and validate it using a Python CLI, built for cloud security engineering.

## Features
- **Terraform**: Deploys a VPC, private S3 bucket, IAM role, and CloudTrail.
- **Python CLI**: Checks S3 encryption, public access (ACLs and policies), and IAM MFA compliance.
- **Security**: Aligns with AWS Well-Architected Framework and CIS Benchmarks.

## Setup (Windows)
1. **Prerequisites**:
   - **AWS CLI**: Install from `https://aws.amazon.com/cli/`.
   - **Terraform**: Download from `https://www.terraform.io/downloads.html`, unzip, and place `terraform.exe` in `terraform/` or add to your PATH.
   - **Python 3.8+**: Install from `https://www.python.org/downloads/`.
   - **Git**: Install from `https://git-scm.com/download/win`.
   - AWS account with AdministratorAccess IAM user.
2. **Deploy Infrastructure**:
   ```cmd
   cd terraform
   terraform init
   terraform apply

## Demo
![S3 Public Access Warning](demo/s3-check.png)