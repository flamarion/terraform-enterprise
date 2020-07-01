provider "aws" {
  region  = var.region
  version = "~> 2.59"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

terraform {
  required_version = "~> 0.12"
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-external-services.tfstate"
    region = "eu-central-1"


    dynamodb_table = "flamarion-hashicorp-locks"
    encrypt        = true
  }
}

data "aws_route53_zone" "selected" {
  name = "hashicorp-success.com."
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-vpc.tfstate"
    region = "eu-central-1"
  }
}

# Load Balancer Security Group
module "tfe_lb_sg" {
  source  = "./modules/sg"
  sg_name = "${var.tag_prefix}-lb-sg"
  sg_desc = "TFE Load Balancer Security Group"
  vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
  sg_tags = {
    Name = "${var.tag_prefix}-lb-sg"
  }

  sg_rules_cidr = {
    http = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      sg_id       = module.tfe_lb_sg.sg_id
    },
    https = {
      description = "Terraform Cloud application via HTTPS"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      sg_id       = module.tfe_lb_sg.sg_id
    },
    replicated = {
      description = "Replicated dashboard"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = var.replicated_port
      to_port     = var.replicated_port
      protocol    = "tcp"
      sg_id       = module.tfe_lb_sg.sg_id
    },
    outbound = {
      description = "Allow all outbound"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      to_port     = 0
      protocol    = "-1"
      from_port   = 0
      sg_id       = module.tfe_lb_sg.sg_id
    }
  }
}

# DB Cluster Security Group
module "tfe_db_sg" {
  source  = "./modules/sg"
  sg_name = "${var.tag_prefix}-db-sg"
  sg_desc = "TFE Database Security Group"
  vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
  sg_tags = {
    Name = "${var.tag_prefix}-db-sg"
  }

  sg_rules_cidr = {
    postgres = {
      description = "Allow access from TFE Instances"
      type        = "ingress"
      cidr_blocks = data.terraform_remote_state.vpc.outputs.subnets
      from_port   = module.tfe_db_cluster.port
      to_port     = module.tfe_db_cluster.port
      protocol    = "tcp"
      sg_id       = module.tfe_db_sg.sg_id
    },
    outbound = {
      description = "Allow all outbound traffic"
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      sg_id       = module.tfe_db_sg.sg_id
    }
  }
}

# TFE Instances Security Group
module "tfe_instances_sg" {
  source  = "./modules/sg"
  sg_name = "${var.tag_prefix}-sg"
  sg_desc = "TFE Instances Security Group"
  vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
  sg_tags = {
    Name = "${var.tag_prefix}-sg"
  }
  source_sgid_rule = "enbled"
  sg_rules_sgid = {
    http = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      source_sgid = module.tfe_lb_sg.sg_id
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      sg_id       = module.tfe_instances_sg.sg_id
    },
    https = {
      description = "Terraform Cloud application via HTTPS"
      type        = "ingress"
      source_sgid = module.tfe_lb_sg.sg_id
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      sg_id       = module.tfe_instances_sg.sg_id
    },
    replicated = {
      description = "Replicated dashboard"
      type        = "ingress"
      source_sgid = module.tfe_lb_sg.sg_id
      from_port   = var.replicated_port
      to_port     = var.replicated_port
      protocol    = "tcp"
      sg_id       = module.tfe_instances_sg.sg_id
    }
  }
}

# Extra security group rules for TFE Instances

resource "aws_security_group_rule" "tfe_ssh" {
  description       = "Allow SSH"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  security_group_id = module.tfe_instances_sg.sg_id
}

resource "aws_security_group_rule" "tfe_outbound" {
  description       = "Outbound traffic is allowed"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = module.tfe_instances_sg.sg_id
}

# RDS Postgre Cluster module
module "tfe_db_cluster" {
  source              = "./modules/db"
  db_engine           = "aurora-postgresql"
  cluster_identifier  = "${var.tag_prefix}-pgsql"
  db_name             = "tfe"
  db_pass             = "SuperS3cure"
  db_user             = "tfe"
  skip_final_snapshot = true
  az_list             = data.terraform_remote_state.vpc.outputs.az
  sg_id_list          = [module.tfe_db_sg.sg_id]
  apply_immediately   = true
  db_subnet_group     = data.terraform_remote_state.vpc.outputs.db_subnet_group
  db_tags = {
    Name = "${var.tag_prefix}-pgsql-cluster"
  }
  instance_identifier = "${var.tag_prefix}-instance"
  instance_type       = "db.t3.medium"
  public              = false
}

# S3 Bucket
resource "aws_s3_bucket" "tfe_s3" {
  bucket = "${var.tag_prefix}-es"
  acl    = "private"

  versioning {
    enabled = true
  }
}

# Role, Policies and Instance Profiles
resource "aws_iam_role" "tfe_iam_role" {
  name               = "${var.tag_prefix}-iam-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "tfe_instance_profile" {
  name = "${var.tag_prefix}-instance-profile"
  role = aws_iam_role.tfe_iam_role.name
}

data "aws_iam_policy_document" "ptfe" {
  statement {
    sid    = "AllowS3"
    effect = "Allow"

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.tfe_s3.id}",
      "arn:aws:s3:::${aws_s3_bucket.tfe_s3.id}/*",
    ]

    actions = [
      "s3:*",
    ]
  }
}

resource "aws_iam_role_policy" "tfe_policy" {
  name   = "${var.tag_prefix}-iam-role-policy"
  role   = aws_iam_role.tfe_iam_role.name
  policy = data.aws_iam_policy_document.ptfe.json
}

# SSH Key 
resource "aws_key_pair" "tfe_key" {
  key_name   = "flamarion-tfe"
  public_key = file("~/.ssh/cloud.pub")
}

# Script to boot strap TFE Installation
data "template_file" "userdata" {
  template = file("templates/userdata.tpl")

  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    s3_bucket_name = "${var.tag_prefix}-es"
    s3_region      = aws_s3_bucket.tfe_s3.region
    db_name        = module.tfe_db_cluster.db_name
    db_user        = module.tfe_db_cluster.db_user
    db_pass        = module.tfe_db_cluster.db_pass
    db_port        = module.tfe_db_cluster.port
    db_host        = module.tfe_db_cluster.endpoint
  }
}

# Launch configuration 
resource "aws_launch_configuration" "tfe_instances" {
  name                        = "${var.tag_prefix}-lc"
  image_id                    = var.image_id
  instance_type               = "m5.large"
  iam_instance_profile        = aws_iam_instance_profile.tfe_instance_profile.name
  key_name                    = aws_key_pair.tfe_key.key_name
  security_groups             = [module.tfe_instances_sg.sg_id]
  associate_public_ip_address = true
  user_data                   = data.template_file.userdata.rendered
  root_block_device {
    volume_size = 100
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "tfe_asg" {
  name                 = "${var.tag_prefix}-asg-"
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = data.terraform_remote_state.vpc.outputs.subnet_ids
  launch_configuration = aws_launch_configuration.tfe_instances.name
  target_group_arns = [
    aws_lb_target_group.tfe_lb_tg_http.arn,
    aws_lb_target_group.tfe_lb_tg_https.arn,
    aws_lb_target_group.tfe_lb_tg_https_replicated.arn
  ]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "${var.tag_prefix}-asg-instances"
    propagate_at_launch = true
  }
}

# TFE Load Balancer Module
# module tfe_lb {
#   source = "./modules/lb"

#   lb_name    = "${var.tag_prefix}-lb"
#   lb_type    = "application"
#   lb_sg      = [module.tfe_lb_sg.sg_id]
#   lb_subnets = data.terraform_remote_state.vpc.outputs.subnet_ids
#   lb_tags = {
#     Name = "${var.tag_prefix}-lb"
#   }

#   target_groups = [
#     {
#       tg_name = "${var.tag_prefix}-tg-${var.https_port}"
#       tg_port = var.https_port
#       tg_protocol = "HTTPS"
#       tg_vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
#       tg_dereg_delay = 60
#       tg_slow_start = 300
#       health_check  = {
#         path                = "/_health_check"
#         protocol            = "HTTPS"
#         matcher             = "200"
#         interval            = 30
#         timeout             = 20
#         healthy_threshold   = 2
#         unhealthy_threshold = 10
#       }
#       tg_tags = {
#         Name = "${var.tag_prefix}-tg-${var.https_port}"
#       }
#     }
#   ]
# }

# # Load Balancer (ALB)
resource "aws_lb" "flamarion_lb" {
  name               = "${var.tag_prefix}-lb"
  load_balancer_type = "application"
  security_groups    = [module.tfe_lb_sg.sg_id]
  subnets            = data.terraform_remote_state.vpc.outputs.subnet_ids
  tags = {
    Name = "${var.tag_prefix}-lb"
  }
}

# TFE LB Target groups
resource "aws_lb_target_group" "tfe_lb_tg_https" {
  name                 = "${var.tag_prefix}-tg-${var.https_port}"
  port                 = var.https_port
  protocol             = "HTTPS"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 60
  slow_start           = 300
  health_check {
    path                = "/_health_check"
    protocol            = "HTTPS"
    matcher             = "200"
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_https_replicated" {
  name                 = "${var.tag_prefix}-tg-${var.replicated_port}"
  port                 = var.replicated_port
  protocol             = "HTTPS"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 60
  slow_start           = 180
  health_check {
    path                = "/dashboard"
    protocol            = "HTTPS"
    matcher             = "200,301,302"
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_http" {
  name                 = "${var.tag_prefix}-tg-${var.http_port}"
  port                 = var.http_port
  protocol             = "HTTP"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 60
  slow_start           = 180
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299,300-399"
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# HashiCorp wildcard certificate
data "aws_acm_certificate" "hashicorp_success" {
  domain      = "*.hashicorp-success.com"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# LB Listeners
resource "aws_lb_listener" "tfe_listener_https" {
  load_balancer_arn = aws_lb.flamarion_lb.arn
  port              = var.https_port
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.hashicorp_success.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_https.arn
  }
}

resource "aws_lb_listener" "tfe_listener_https_replicated" {
  load_balancer_arn = aws_lb.flamarion_lb.arn
  port              = var.replicated_port
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.hashicorp_success.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_https_replicated.arn
  }
}

resource "aws_lb_listener" "tfe_listener_http" {
  load_balancer_arn = aws_lb.flamarion_lb.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_http.arn
  }
}

# LB Listener Rules
resource "aws_lb_listener_rule" "asg_https" {
  listener_arn = aws_lb_listener.tfe_listener_https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_https.arn
  }
}

resource "aws_lb_listener_rule" "asg_https_replicated" {
  listener_arn = aws_lb_listener.tfe_listener_https_replicated.arn
  priority     = 101

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_https_replicated.arn
  }
}

resource "aws_lb_listener_rule" "asg_http" {
  listener_arn = aws_lb_listener.tfe_listener_http.arn
  priority     = 102

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lb_tg_http.arn
  }
}

# Route53 DNS Record
resource "aws_route53_record" "flamarion" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "flamarion.hashicorp-success.com"
  type    = "A"
  alias {
    name                   = aws_lb.flamarion_lb.dns_name
    zone_id                = aws_lb.flamarion_lb.zone_id
    evaluate_target_health = true
  }
}
