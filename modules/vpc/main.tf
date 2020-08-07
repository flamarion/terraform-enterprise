terraform {
  required_version = "~> 0.12"

  required_providers {
    aws = "~> 2.59"
  }

}

locals {
  vpc_id  = aws_vpc.vpc.id
  az_size = var.az
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  tags = var.vpc_tags
}

resource "aws_eip" "eip" {
  count = var.enable_nat_gateway ? 1 : 0
  vpc   = true
  tags = var.eip_tags
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = var.az[count.index]
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = var.map_public_ip
  tags = var.public_subnet_tags 
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.az[count.index]
  cidr_block        = var.private_subnets[count.index]
  tags = var.private_subnet_tags
}

resource "aws_subnet" "database" {
  count             = length(var.database_subnets) > 0 ? length(var.database_subnets) : 0
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.az[count.index]
  cidr_block        = var.database_subnets[count.index]
  tags = var.database_subnet_tags
}

resource "aws_db_subnet_group" "db_subnet_group" {
  count       = var.create_db_subnet_group ? 1 : 0
  name        = "db-subnet-group"
  description = "Database subnet group"
  subnet_ids  = aws_subnet.database.*.id
  tags = var.database_subnet_group_tags
}

resource "aws_nat_gateway" "nat_gw" {
  count         = var.enable_nat_gateway && length(var.private_subnets) > 0 ? 1 : 0
  allocation_id = aws_eip.eip[0].id
  subnet_id     = aws_subnet.private[0].id
  tags = var.nat_gw_tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = var.igw_tags
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = var.public_rt_tags
}

resource "aws_route_table" "private_rt" {
  count  = length(var.private_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = var.private_rt_tags
}

resource "aws_route_table" "db_rt" {
  count  = length(var.database_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = var.db_rt_tags
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_route" {
  count                  = var.enable_nat_gateway && length(var.private_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

resource "aws_route" "db_route" {
  count                  = var.enable_nat_gateway && length(var.database_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.db_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

resource "aws_route_table_association" "public_rta" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  count          = var.enable_nat_gateway && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt[0].id
}

resource "aws_route_table_association" "db_rta" {
  count          = var.enable_nat_gateway && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.db_rt[0].id
}
