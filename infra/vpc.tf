# VPC for Glue Job Execution
resource "aws_vpc" "glue_vpc" {
  count = var.enable_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = local.vpc_name
    }
  )
}

# Private Subnet for Glue Jobs
resource "aws_subnet" "glue_private" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.glue_vpc[0].id
  cidr_block        = local.private_subnet_cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name_prefix}-private-subnet"
    }
  )
}

# Security Group for Glue Jobs
resource "aws_security_group" "glue_jobs" {
  count = var.enable_vpc ? 1 : 0

  name        = local.glue_sg_name
  description = "Security group for Glue jobs"
  vpc_id      = aws_vpc.glue_vpc[0].id

  # Allow outbound traffic to internet (for downloading packages, etc.)
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow communication between Glue jobs
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Jobs Security Group"
    }
  )
}

# Security Group for database access (optional)
resource "aws_security_group" "glue_database_access" {
  count = var.enable_vpc ? 1 : 0

  name        = local.database_access_sg_name
  description = "Security group for Glue database access"
  vpc_id      = aws_vpc.glue_vpc[0].id

  # Allow inbound from Glue security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_jobs[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Database Access Security Group"
    }
  )
}

# NAT Gateway for private subnet to access internet (optional)
resource "aws_eip" "glue_nat" {
  count = var.enable_vpc ? 1 : 0

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "Glue NAT Gateway EIP"
    }
  )

  depends_on = [aws_internet_gateway.glue]
}

# Internet Gateway
resource "aws_internet_gateway" "glue" {
  count = var.enable_vpc ? 1 : 0

  vpc_id = aws_vpc.glue_vpc[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "Glue IGW"
    }
  )
}

# NAT Gateway
resource "aws_nat_gateway" "glue" {
  count = var.enable_vpc ? 1 : 0

  allocation_id = aws_eip.glue_nat[0].id
  subnet_id     = aws_subnet.glue_private[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "Glue NAT Gateway"
    }
  )

  depends_on = [aws_internet_gateway.glue]
}

# Route table for private subnet
resource "aws_route_table" "glue_private" {
  count = var.enable_vpc ? 1 : 0

  vpc_id = aws_vpc.glue_vpc[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.glue[0].id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Private Route Table"
    }
  )
}

# Associate route table with subnet
resource "aws_route_table_association" "glue_private" {
  count = var.enable_vpc ? 1 : 0

  subnet_id      = aws_subnet.glue_private[0].id
  route_table_id = aws_route_table.glue_private[0].id
}
