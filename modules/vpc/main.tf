terraform {
  required_version = "~> 0.12"

  required_providers {
    aws = "~> 2.59"
  }

}

locals {
  vpc_id  = aws_vpc.tfe_vpc.id
  az_size = var.az
}

resource "aws_vpc" "tfe_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  tags = merge(
    var.vpc_tags,
    {
      Name = "${var.tag_prefix}-vpc"
    }
  )
}

resource "aws_eip" "tfe_eip" {
  count = var.enable_nat_gateway ? 1 : 0
  vpc   = true
  tags = merge(
    var.eip_tags,
    {
      Name = "${var.tag_prefix}-eip"
    }
  )
}


resource "aws_subnet" "tfe_public" {
  count                   = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  vpc_id                  = aws_vpc.tfe_vpc.id
  availability_zone       = var.az[count.index]
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = var.map_public_ip
  tags = merge(
    var.public_subnet_tags,
    {
      Name = "${var.tag_prefix}-public-subnet"
    }
  )
}

resource "aws_subnet" "tfe_private" {
  count             = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  vpc_id            = aws_vpc.tfe_vpc.id
  availability_zone = var.az[count.index]
  cidr_block        = var.private_subnets[count.index]
  tags = merge(
    var.private_subnet_tags,
    {
      Name = "${var.tag_prefix}-private-subnet"
    }
  )
}

resource "aws_subnet" "tfe_database" {
  count             = length(var.database_subnets) > 0 ? length(var.database_subnets) : 0
  vpc_id            = aws_vpc.tfe_vpc.id
  availability_zone = var.az[count.index]
  cidr_block        = var.database_subnets[count.index]
  tags = merge(
    var.database_subnet_tags,
    {
      Name = "${var.tag_prefix}-database-seubnet"
    }
  )
}

resource "aws_db_subnet_group" "tfe_db_subnet_group" {
  count       = var.create_db_subnet_group ? 1 : 0
  name        = "${var.tag_prefix}-db-subnet-group"
  description = "Database subnet group ${var.tag_prefix}"
  subnet_ids  = aws_subnet.tfe_database.*.id
  tags = merge(
    var.database_subnet_group_tags,
    {
      Name = "${var.tag_prefix}-db-subnet-group"
    }
  )
}

resource "aws_nat_gateway" "tfe_nat_gw" {
  count         = var.enable_nat_gateway && length(var.private_subnets) > 0 ? 1 : 0
  allocation_id = aws_eip.tfe_eip[0].id
  subnet_id     = aws_subnet.tfe_private[0].id
  tags = merge(
    var.nat_gw_tags,
    {
      Name = "${var.tag_prefix}-nat-gw"
    }
  )
}

locals {
  single_nat_gateway = "1"
}


resource "aws_internet_gateway" "tfe_igw" {
  vpc_id = aws_vpc.tfe_vpc.id
  tags = merge(
    var.igw_tags,
    {
      Name = "${var.tag_prefix}-igw"
    }
  )
}

resource "aws_route_table" "tfe_public_rt" {
  vpc_id = aws_vpc.tfe_vpc.id
  tags = {
    Name = "${var.tag_prefix}-public-route-table"
  }
}

resource "aws_route_table" "tfe_private_rt" {
  count  = length(var.private_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.tfe_vpc.id
  tags = {
    Name = "${var.tag_prefix}-private-route-table"
  }
}

resource "aws_route_table" "tfe_db_rt" {
  count  = length(var.database_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.tfe_vpc.id
  tags = {
    Name = "${var.tag_prefix}-private-route-table"
  }
}

resource "aws_route" "tfe_public_route" {
  route_table_id         = aws_route_table.tfe_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.tfe_igw.id
}

resource "aws_route" "tfe_private_route" {
  count                  = var.enable_nat_gateway && length(var.private_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.tfe_private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.tfe_nat_gw[count.index].id
}

resource "aws_route" "tfe_db_route" {
  count                  = var.enable_nat_gateway && length(var.database_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.tfe_db_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.tfe_nat_gw[count.index].id
}

resource "aws_route_table_association" "tfe_public_rta" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.tfe_public[count.index].id
  route_table_id = aws_route_table.tfe_public_rt.id
}

resource "aws_route_table_association" "tfe_private_rta" {
  count          = var.enable_nat_gateway && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  subnet_id      = aws_subnet.tfe_private[count.index].id
  route_table_id = aws_route_table.tfe_private_rt[0].id
}

resource "aws_route_table_association" "tfe_db_rta" {
  count          = var.enable_nat_gateway && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0
  subnet_id      = aws_subnet.tfe_database[count.index].id
  route_table_id = aws_route_table.tfe_db_rt[0].id
}
