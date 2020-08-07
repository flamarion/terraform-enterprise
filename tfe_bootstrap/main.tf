provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_providers {
    aws = "~> 2.59"
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

locals {
  owner = "flamarion"
}

module "tfe_vpc" {

  source = "../modules/vpc"

  # VPC
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnets
  az                     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets         = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets        = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets       = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
  create_db_subnet_group = true
  map_public_ip          = true
  enable_nat_gateway     = true

  #tags
  vpc_tags = {
    Name = "${local.owner}-vpc"
  }
  eip_tags = {
    Name = "${local.owner}-eip"
  }
  public_subnet_tags = {
    Name = "${local.owner}-public-subnet"
  }
  private_subnet_tags = {
    Name = "${local.owner}-private-subnet"
  }
  database_subnet_tags = {
    Name = "${local.owner}-db-subnet"
  }
  database_subnet_group_tags = {
    Name = "${local.owner}-db-subnet-group"
  }
  nat_gw_tags = {
    Name = "${local.owner}-nat-gw"
  }
  igw_tags = {
    Name = "${local.owner}-igw"
  }
  public_rt_tags = {
    Name = "${local.owner}-public-rt"
  }
  private_rt_tags = {
    Name = "${local.owner}-private-rt"
  }
  db_rt_tags = {
    Name = "${local.owner}-db-rt"
  }
}
