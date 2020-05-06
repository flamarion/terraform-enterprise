provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.59"
}

terraform {
  required_version = "~> 0.12"
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-vpc.tfstate"
    region = "eu-central-1"


    dynamodb_table = "flamarion-hashicorp-locks"
    encrypt        = true
  }
}

module "tfe_vpc" {

  source = "../../../modules/vpc"

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
  tag_prefix             = "flamarion-tfe"
}
