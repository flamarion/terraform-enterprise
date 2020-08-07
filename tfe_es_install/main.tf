provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-es.tfstate"
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
  key_name   = "flamarion-tfe-es"
  public_key = file("~/.ssh/cloud.pub")
}

module "tfe_es" {
  source     = "../tfe_es_module"
  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  tag_prefix = "flamarion-tfe-es"
  # Database
  db_name          = "tfe"
  db_pass          = "SuperS3cret"
  db_user          = "tfe"
  db_instance_type = "db.t3.medium"
  db_port          = module.tfe_es.db_cluster_port
  db_endpoint      = module.tfe_es.db_cluster_endpoint
  db_sg_id_list    = [module.tfe_es.db_sg_id]
  db_subnet_group  = data.terraform_remote_state.vpc.outputs.db_subnet_group
  az_list          = data.terraform_remote_state.vpc.outputs.az
  # Lauch Configuration
  image_id         = "ami-0ca5b487ed9f8209f"
  instance_type    = "m5.large"
  key_name         = aws_key_pair.tfe_key.key_name
  instance_sg_list = [module.tfe_es.instances_sg_id]
  # Autoscaling Group
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = data.terraform_remote_state.vpc.outputs.subnet_ids
  # Load Balancer
  subnets          = data.terraform_remote_state.vpc.outputs.subnet_ids
  lb_sg            = [module.tfe_es.lb_sg_id]
  http_port        = var.http_port
  http_proto       = var.http_proto
  https_port       = var.https_port
  https_proto      = var.https_proto
  replicated_port  = var.replicated_port
  replicated_proto = var.replicated_proto
  # DNS
  dns_record_name = "flamarion-es"
  # LB SG Rules
  sg_lb_rules_cidr = {
    http = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.lb_sg_id
    },
    https = {
      description = "Terraform Cloud application via HTTPS"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.lb_sg_id
    },
    replicated = {
      description = "Replicated dashboard"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.replicated_port
      to_port     = var.replicated_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.lb_sg_id
    },
    outbound = {
      description = "Allow all outbound"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      to_port     = 0
      protocol    = "-1"
      from_port   = 0
      sg_id       = module.tfe_es.lb_sg_id
    }
  }
  # DB Cluster SG Rules 
  sg_db_rules_cidr = {
    postgres = {
      description = "Allow access from TFE Instances"
      type        = "ingress"
      cidr_blocks = data.terraform_remote_state.vpc.outputs.subnets
      from_port   = module.tfe_es.db_cluster_port
      to_port     = module.tfe_es.db_cluster_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.db_sg_id
    },
    outbound = {
      description = "Allow all outbound traffic"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      sg_id       = module.tfe_es.db_sg_id
    }
  }
  # Instance rules based on CIDR sources
  sg_instance_rules_sgid = {
    http = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      source_sgid = module.tfe_es.lb_sg_id
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.instances_sg_id
    },
    https = {
      description = "Terraform Cloud application via HTTPS"
      type        = "ingress"
      source_sgid = module.tfe_es.lb_sg_id
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.instances_sg_id
    },
    replicated = {
      description = "Replicated dashboard"
      type        = "ingress"
      source_sgid = module.tfe_es.lb_sg_id
      from_port   = var.replicated_port
      to_port     = var.replicated_port
      protocol    = "tcp"
      sg_id       = module.tfe_es.instances_sg_id
    }
  }
  # Instance rules based on SG ID rules
  sg_instance_rules_cidr = {
    ssh = {
      description = "Allow SSH"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = "22"
      to_port     = "22"
      protocol    = "tcp"
      sg_id       = module.tfe_es.instances_extra_sg_id
    },
    outbound = {
      description = "Allow all outbound traffic"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      sg_id       = module.tfe_es.instances_extra_sg_id
    }
  }
}
