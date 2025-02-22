provider "aws" {
  region = "us-west-1"
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name}-${var.vpc_name}" })
}
resource "aws_subnet" "public" {
  count                   = length(var.vpc_public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.vpc_public_subnets, count.index)
  availability_zone       = element(var.vpc_availability_zones, count.index)
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.name}-public-${count.index}", Type = "Public Subnets" })
}

resource "aws_subnet" "private" {
  count                   = length(var.vpc_private_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.vpc_private_subnets, count.index)
  availability_zone       = element(var.vpc_availability_zones, count.index)
  tags                    = merge(local.common_tags, { Name = "${local.name}-private-${count.index}", Type = "Private Subnets" })
}

resource "aws_subnet" "database" {
  count                   = length(var.vpc_database_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.vpc_database_subnets, count.index)
  availability_zone       = element(var.vpc_availability_zones, count.index)
  tags                    = merge(local.common_tags, { Name = "${local.name}-database-${count.index}", Type = "Private Database Subnets" })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = local.common_tags
}
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}
resource "aws_nat_gateway" "example" {
  count          = var.vpc_enable_nat_gateway ? 1 : 0
  depends_on     = [aws_eip.nat]
  allocation_id  = aws_eip.nat.id
  subnet_id      = var.vpc_single_nat_gateway ? element(aws_subnet.public[*].id, 0) : element(aws_subnet.public[*].id, count.index)
  tags           = local.common_tags
}

resource "aws_eip" "nat" {
  vpc = true
  tags = local.common_tags
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example.id
  }
  tags = local.common_tags
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private[*].id)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}
resource "aws_db_subnet_group" "database" {
  count = var.vpc_create_database_subnet_group ? 1 : 0
  name = "${local.name}-database"
  subnet_ids = aws_subnet.database[*].id
  tags = merge(local.common_tags, { Type = "Private Database Subnets" })
}
