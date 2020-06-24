provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_providers {
    aws  = "~> 2.59"
  }
  required_version = "~> 0.12"
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-vpc.tfstate"
    region = "eu-central-1"


    dynamodb_table = "flamarion-hashicorp-locks"
    encrypt        = true
  }
}

data "aws_availability_zones" "az" {
  state = "available"
}

resource "aws_vpc" "tfe_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "tfe_public" {
  count                   = length(data.aws_availability_zones.az.names)
  vpc_id                  = aws_vpc.tfe_vpc.id
  availability_zone       = data.aws_availability_zones.az.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.tfe_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.tag_prefix}-public-subnet"
  }
}

resource "aws_subnet" "tfe_private" {
  count                   = length(data.aws_availability_zones.az.names)
  vpc_id                  = aws_vpc.tfe_vpc.id
  availability_zone       = data.aws_availability_zones.az.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.tfe_vpc.cidr_block, 8, count.index + 3)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.tag_prefix}-private-subnet"
  }
}

resource "aws_db_subnet_group" "db" {
  name_prefix = var.tag_prefix
  description = "${var.tag_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.tfe_private.*.id
  tags = {
    Name = "${var.tag_prefix}-db-subnet-group"
  }
}

resource "aws_internet_gateway" "tfe_igw" {
  vpc_id = aws_vpc.tfe_vpc.id
  tags = {
    Name = "${var.tag_prefix}-igw"
  }
}

resource "aws_route_table" "tfe_rt" {
  vpc_id = aws_vpc.tfe_vpc.id
  tags = {
    Name = "${var.tag_prefix}-route-table"
  }
}

resource "aws_route" "tfe_default_route" {
  route_table_id         = aws_route_table.tfe_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.tfe_igw.id
}

resource "aws_route_table_association" "tfe_rta" {
  count          = length(data.aws_availability_zones.az.names)
  subnet_id      = aws_subnet.tfe_public[count.index].id
  route_table_id = aws_route_table.tfe_rt.id
}
