provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-md.tfstate"
    region = "eu-central-1"


    dynamodb_table = "flamarion-hashicorp-locks"
    encrypt        = true
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-vpc.tfstate"
    region = "eu-central-1"
  }
}

resource "aws_key_pair" "tfe_key" {
  key_name   = "flamarion-tfe-md"
  public_key = file("~/.ssh/cloud.pub")
}


module "tfe_md" {
  source           = "../tfe_md_module"
  ami_id           = "ami-0ca5b487ed9f8209f"
  tag_prefix       = "flamarion-tfe-md"
  vpc_id           = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_id        = data.terraform_remote_state.vpc.outputs.public_subnets_id[0]
  subnets          = data.terraform_remote_state.vpc.outputs.public_subnets_id
  instance_type    = "m5.large"
  root_volume_size = 50
  ebs_volume_size  = 100
  ebs_device_name  = "/dev/sdf"
  ebs_mount_point  = "/opt/tfe"
  ebs_file_system  = "xfs"
  key_name         = aws_key_pair.tfe_key.key_name
  dns_record_name  = "flamarion-md"
  admin_password   = "SuperS3cret"
  rel_seq          = var.rel_seq
  sg_rules_cidr = {
    ssh = {
      description = "SSH"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      sg_id       = module.tfe_md.sg_id
    },
    http = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      sg_id       = module.tfe_md.sg_id
    },
    https = {
      description = "Terraform Cloud application via HTTPS"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      sg_id       = module.tfe_md.sg_id
    },
    replicated = {
      description = "Replicated dashboard"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.replicated_port
      to_port     = var.replicated_port
      protocol    = "tcp"
      sg_id       = module.tfe_md.sg_id
    },
    outbound = {
      description = "Allow all outbound"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      to_port     = 0
      protocol    = "-1"
      from_port   = 0
      sg_id       = module.tfe_md.sg_id
    }
  }
}
