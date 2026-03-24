# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "glue_vpc" {
  count = var.enable_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

# =============================================================================
# SUBNETS
# One public subnet for NAT Gateway.
# Three private subnets across 3 AZs for Glue + future MSK brokers (multi-AZ).
# =============================================================================

# Public subnet — NAT Gateway lives here
resource "aws_subnet" "public" {
  count = var.enable_vpc ? 1 : 0

  vpc_id                  = aws_vpc.glue_vpc[0].id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-public-subnet"
    Tier = "public"
  })
}

# Private subnet AZ-a — primary Glue subnet + MSK broker 1
resource "aws_subnet" "private_az1" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.glue_vpc[0].id
  cidr_block        = local.private_subnet_cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-private-subnet-az1"
    Tier = "private"
  })
}

# Private subnet AZ-b — MSK broker 2
resource "aws_subnet" "private_az2" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.glue_vpc[0].id
  cidr_block        = local.private_subnet_cidr_az2
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-private-subnet-az2"
    Tier = "private"
  })
}

# Private subnet AZ-c — MSK broker 3
resource "aws_subnet" "private_az3" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.glue_vpc[0].id
  cidr_block        = local.private_subnet_cidr_az3
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-private-subnet-az3"
    Tier = "private"
  })
}

# =============================================================================
# INTERNET GATEWAY + NAT GATEWAY
# NAT Gateway is in the PUBLIC subnet so private subnets can reach the internet.
# =============================================================================

resource "aws_internet_gateway" "glue" {
  count = var.enable_vpc ? 1 : 0

  vpc_id = aws_vpc.glue_vpc[0].id

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = var.enable_vpc ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.glue]
}

resource "aws_nat_gateway" "glue" {
  count = var.enable_vpc ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id   # NAT must be in PUBLIC subnet

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-nat-gw"
  })

  depends_on = [aws_internet_gateway.glue]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# Public route table — routes 0.0.0.0/0 to IGW
resource "aws_route_table" "public" {
  count = var.enable_vpc ? 1 : 0

  vpc_id = aws_vpc.glue_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.glue[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.enable_vpc ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# Private route table — all 3 private subnets share one route via NAT
resource "aws_route_table" "private" {
  count = var.enable_vpc ? 1 : 0

  vpc_id = aws_vpc.glue_vpc[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.glue[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private_az1" {
  count = var.enable_vpc ? 1 : 0

  subnet_id      = aws_subnet.private_az1[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_az2" {
  count = var.enable_vpc ? 1 : 0

  subnet_id      = aws_subnet.private_az2[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_az3" {
  count = var.enable_vpc ? 1 : 0

  subnet_id      = aws_subnet.private_az3[0].id
  route_table_id = aws_route_table.private[0].id
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Glue jobs security group
resource "aws_security_group" "glue_jobs" {
  count = var.enable_vpc ? 1 : 0

  name        = local.glue_sg_name
  description = "Security group for Glue jobs"
  vpc_id      = aws_vpc.glue_vpc[0].id

  # Glue workers must be able to talk to each other (Spark driver <-> executor)
  ingress {
    description = "Glue self-referencing rule (Spark inter-node)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # All outbound allowed — needed to reach S3, Glue APIs, MSK, etc.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Glue Jobs Security Group"
  })
}

# MSK security group — ready for when MSK is provisioned
resource "aws_security_group" "msk" {
  count = var.enable_vpc ? 1 : 0

  name        = local.msk_sg_name
  description = "Security group for MSK Kafka brokers"
  vpc_id      = aws_vpc.glue_vpc[0].id

  # Plaintext Kafka — from Glue SG only
  ingress {
    description     = "Kafka plaintext from Glue"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_jobs[0].id]
  }

  # TLS Kafka — from Glue SG only
  ingress {
    description     = "Kafka TLS from Glue"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_jobs[0].id]
  }

  # IAM/SASL auth port — from Glue SG only
  ingress {
    description     = "Kafka IAM/SASL from Glue"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_jobs[0].id]
  }

  # MSK broker inter-broker communication
  ingress {
    description = "MSK inter-broker"
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    self        = true
  }

  # ZooKeeper (MSK manages this internally but rule is required)
  ingress {
    description = "ZooKeeper inter-broker"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "MSK Security Group"
  })
}

# Kept for any future RDS/database access
resource "aws_security_group" "glue_database_access" {
  count = var.enable_vpc ? 1 : 0

  name        = local.database_access_sg_name
  description = "Security group for Glue database access"
  vpc_id      = aws_vpc.glue_vpc[0].id

  ingress {
    description     = "PostgreSQL from Glue"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_jobs[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Glue Database Access Security Group"
  })
}

# =============================================================================
# GLUE VPC CONNECTION
# Registers the VPC with Glue so jobs can connect to MSK and other VPC resources.
# When adding MSK, reference this connection in the Glue streaming job.
# =============================================================================

resource "aws_glue_connection" "vpc" {
  count = var.enable_vpc ? 1 : 0

  name            = "${local.resource_name_prefix}-vpc-connection"
  description     = "VPC connection for Glue jobs — enables access to MSK and other VPC resources"
  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = data.aws_availability_zones.available.names[0]
    security_group_id_list = [aws_security_group.glue_jobs[0].id]
    subnet_id              = aws_subnet.private_az1[0].id
  }

  tags = merge(local.common_tags, {
    Name = "Glue VPC Connection"
  })
}
