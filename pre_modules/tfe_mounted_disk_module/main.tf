terraform {
  required_providers {
    aws      = "~> 2.59"
    template = "~> 2.1"
  }
  required_version = "~> 0.12"
}

# Load Balancer Security Group
module "tfe_lb_sg" {
  source  = "./modules/sg"
  sg_name = "${var.tag_prefix}-lb-sg"
  sg_desc = "TFE Load Balancer Security Group"
  vpc_id  = var.vpc_id
  sg_tags = {
    Name = "${var.tag_prefix}-lb-sg"
  }

  sg_rules_cidr = var.sg_rules_cidr
}

# TFE Instances Security Group
module "tfe_instances_sg" {
  source  = "./modules/sg"
  sg_name = "${var.tag_prefix}-sg"
  sg_desc = "TFE Instances Security Group"
  vpc_id  = var.vpc_id
  sg_tags = {
    Name = "${var.tag_prefix}-sg"
  }
  source_sgid_rule = "enbled"
  sg_rules_sgid    = var.sg_rules_sgid
}



# Script to boot strap TFE Installation
data "template_file" "userdata" {
  template = file("templates/userdata.tpl")

  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    disk_path      = var.disk_path
    lb_fqdn        = aws_route53_record.flamarion.fqdn
  }
}


# resource "aws_ebs_volume" "tfe_data" {
#   availability_zone = aws_autoscaling_group.tfe_asg.availability_zone
# }


# Launch configuration 
resource "aws_launch_configuration" "tfe_instances" {
  name                        = "${var.tag_prefix}-lc"
  image_id                    = var.image_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  security_groups             = [module.tfe_instances_sg.sg_id]
  associate_public_ip_address = false
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
  name                 = "${var.tag_prefix}-asg"
  max_size             = 1
  min_size             = 1
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
data "aws_route53_zone" "selected" {
  name = "hashicorp-success.com."
}

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
