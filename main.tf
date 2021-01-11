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


module "tfe_demo" {
  source           = "./tfe_demo_module"
  ami              = "ami-0ca5b487ed9f8209f"
  owner            = "flamarion-tfe-demo"
  vpc_id           = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_id        = data.terraform_remote_state.vpc.outputs.public_subnets_id[0]
  subnets          = data.terraform_remote_state.vpc.outputs.public_subnets_id
  instance_type    = "m5.large"
  root_volume_size = 100
  key_name         = aws_key_pair.tfe_key.key_name
  dns_record_name  = "flamarion-demo"
  admin_password   = "SuperS3cret"
  rel_seq          = var.rel_seq
  rep_version      = ""
  sg_rules_cidr = {
    ssh = {
      description       = "SSH"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = 22
      to_port           = 22
      protocol          = "tcp"
      security_group_id = module.tfe_demo.sg_id
    },
    http = {
      description       = "Terraform Cloud application via HTTP"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = var.http_port
      to_port           = var.http_port
      protocol          = "tcp"
      security_group_id = module.tfe_demo.sg_id
    },
    https = {
      description       = "Terraform Cloud application via HTTPS"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = var.https_port
      to_port           = var.https_port
      protocol          = "tcp"
      security_group_id = module.tfe_demo.sg_id
    },
    replicated = {
      description       = "Replicated dashboard"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = var.replicated_port
      to_port           = var.replicated_port
      protocol          = "tcp"
      security_group_id = module.tfe_demo.sg_id
    },
    outbound = {
      description       = "Allow all outbound"
      type              = "egress"
      cidr_blocks       = ["0.0.0.0/0"]
      to_port           = 0
      protocol          = "-1"
      from_port         = 0
      security_group_id = module.tfe_demo.sg_id
    }
  }
}
