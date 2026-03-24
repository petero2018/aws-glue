# Terraform Backend Configuration
# Remote state stored in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "aws-glue-terraform-state-613261654184"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
  }
}
