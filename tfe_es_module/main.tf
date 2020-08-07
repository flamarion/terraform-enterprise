terraform {
  required_providers {
    aws      = "~> 2.59"
    template = "~> 2.1"
    random   = "~> 2.3"
  }
  required_version = "~> 0.12"
}


# Load Balancer Security Group
module "tfe_lb_sg" {
  source  = "../modules/sg"
  sg_name = "${var.tag_prefix}-lb-sg"
  sg_desc = "TFE Load Balancer Security Group"
  vpc_id  = var.vpc_id
  tags = {
    Name = "${var.tag_prefix}-lb-sg"
  }

  sg_rules_cidr = var.sg_lb_rules_cidr
}

# DB Cluster Security Group
module "tfe_db_sg" {
  source  = "../modules/sg"
  sg_name = "${var.tag_prefix}-db-sg"
  sg_desc = "TFE Database Security Group"
  vpc_id  = var.vpc_id
  tags = {
    Name = "${var.tag_prefix}-db-sg"
  }
  sg_rules_cidr = var.sg_db_rules_cidr
}

# TFE Instances Security Group
module "tfe_instances_sg" {
  source  = "../modules/sg"
  sg_name = "${var.tag_prefix}-sgid-sg"
  sg_desc = "TFE Instances Security Group - SGID"
  vpc_id  = var.vpc_id
  tags = {
    Name = "${var.tag_prefix}-sgid-sg"
  }
  source_sgid_rule = "enabled"
  sg_rules_sgid    = var.sg_instance_rules_sgid
}

# Extra security group rules for TFE Instances
module "tfe_instances_extra_sg" {
  source  = "../modules/sg"
  sg_name = "${var.tag_prefix}-cidr-sg"
  sg_desc = "TFE Instances Security Group - CIDR"
  vpc_id  = var.vpc_id
  tags = {
    Name = "${var.tag_prefix}-cidr-sg"
  }
  sg_rules_cidr = var.sg_instance_rules_cidr
}

# RDS Postgre Cluster module
module "tfe_db_cluster" {
  source              = "../modules/db"
  db_engine           = "aurora-postgresql"
  cluster_identifier  = "${var.tag_prefix}-pgsql"
  db_name             = var.db_name
  db_user             = var.db_user
  db_pass             = var.db_pass
  skip_final_snapshot = true
  az_list             = var.az_list
  sg_id_list          = var.db_sg_id_list
  apply_immediately   = true
  db_subnet_group     = var.db_subnet_group
  db_tags = {
    Name = "${var.tag_prefix}-pgsql-cluster"
  }
  instance_identifier = "${var.tag_prefix}-instance"
  instance_type       = var.db_instance_type
  public              = false
}

#Random id
resource "random_id" "id" {
  byte_length = 3
}

# S3 Bucket
resource "aws_s3_bucket" "tfe_s3" {
  bucket = "${var.tag_prefix}-es-${random_id.id.hex}"
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


# Script to boot strap TFE Installation
data "template_file" "tfe_config" {
  template = file("${path.module}/templates/tfe_config.sh.tpl")

  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    lb_fqdn        = aws_route53_record.flamarion.fqdn
    s3_bucket_name = "${var.tag_prefix}-es-${random_id.id.hex}"
    s3_region      = aws_s3_bucket.tfe_s3.region
    db_name        = var.db_name
    db_user        = var.db_user
    db_pass        = var.db_pass
    db_port        = var.db_port
    db_host        = var.db_endpoint
  }
}

# Launch configuration 
resource "aws_launch_configuration" "tfe_instances" {
  name                        = "${var.tag_prefix}-lc"
  image_id                    = var.image_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.tfe_instance_profile.name
  key_name                    = var.key_name
  security_groups             = var.instance_sg_list
  associate_public_ip_address = true
  user_data                   = data.template_file.tfe_config.rendered
  root_block_device {
    volume_size = 100
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "tfe_asg" {
  name                 = "${var.tag_prefix}-asg"
  max_size             = var.max_size
  min_size             = var.min_size
  vpc_zone_identifier  = var.vpc_zone_identifier
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


# Load Balancer (ALB)
resource "aws_lb" "flamarion_lb" {
  name               = "${var.tag_prefix}-lb"
  load_balancer_type = "application"
  security_groups    = var.lb_sg
  subnets            = var.subnets
  tags = {
    Name = "${var.tag_prefix}-lb"
  }
}

# TFE LB Target groups
resource "aws_lb_target_group" "tfe_lb_tg_https" {
  name                 = "${var.tag_prefix}-tg-${var.https_port}"
  port                 = var.https_port
  protocol             = var.https_proto
  vpc_id               = var.vpc_id
  # deregistration_delay = 30
  slow_start           = 300
  health_check {
    path                = "/_health_check"
    protocol            = var.https_proto
    matcher             = "200-299,300-399"
    interval            = 90
    timeout             = 60
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_https_replicated" {
  name                 = "${var.tag_prefix}-tg-${var.replicated_port}"
  port                 = var.replicated_port
  protocol             = var.replicated_proto
  vpc_id               = var.vpc_id
  # deregistration_delay = 30
  slow_start           = 300
  health_check {
    path                = "/dashboard"
    protocol            = var.replicated_proto
    matcher             = "200-299,300-399"
    interval            = 90
    timeout             = 60
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_http" {
  name                 = "${var.tag_prefix}-tg-${var.http_port}"
  port                 = var.http_port
  protocol             = var.http_proto
  vpc_id               = var.vpc_id
  # deregistration_delay = 30
  slow_start           = 300
  health_check {
    path                = "/"
    protocol            = var.http_proto
    matcher             = "200-299,300-399"
    interval            = 90
    timeout             = 60
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
  protocol          = var.https_proto
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
  protocol          = var.replicated_proto
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
  protocol          = var.http_proto

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
data "aws_route53_zone" "selected" {
  name = "hashicorp-success.com."
}

resource "aws_route53_record" "flamarion" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "${var.dns_record_name}.hashicorp-success.com"
  type    = "A"
  alias {
    name                   = aws_lb.flamarion_lb.dns_name
    zone_id                = aws_lb.flamarion_lb.zone_id
    evaluate_target_health = true
  }
}
