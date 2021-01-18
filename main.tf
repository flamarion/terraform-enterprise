provider "aws" {
  region = "eu-central-1"
}

terraform {

  required_providers {
    aws      = "~> 3.22"
    template = "~> 2.2"
    random   = "~> 3.0"
  }
  required_version = "~> 0.14"

  backend "remote" {
    organization = "FlamaCorp"

    workspaces {
      name = "tfe-aws-demo"
    }
  }
}

data "terraform_remote_state" "vpc" {
  backend = "remote"

  config = {
    organization = "FlamaCorp"
    workspaces = {
      name = "tf-aws-vpc"
    }
  }
}

resource "aws_key_pair" "tfe_key" {
  key_name   = "flamarion-tfe-demo"
  public_key = var.cloud_pub
}

