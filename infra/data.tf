# AWS Account ID
data "aws_caller_identity" "current" {}

# AWS Region
data "aws_region" "current" {}

# Available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}
