terraform {
  required_providers {
    aws      = "~> 2.59"
    template = "~> 2.1"
    random   = "~> 2.3"
  }
  required_version = "~> 0.12"
}

# Security Group
module "sg" {
  source  = "github.com/flamarion/terraform-aws-sg?ref=v0.0.4"
  name = "${var.owner}-tfe-demo-sg"
  description = "Security Group"
  vpc_id  = var.vpc_id
  sg_tags = {
    Name = "${var.owner}-tfe-demo-sg"
  }

  sg_rules_cidr = var.sg_rules_cidr
}

# Script to install TFE
data "template_file" "config_files" {
  template = file("${path.module}/templates/userdata.tpl")
  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    lb_fqdn        = aws_route53_record.flamarion.fqdn
  }
}

# Instance configuration
module "tfe_instance" {
  source                      = "github.com/flamarion/terraform-aws-ec2?ref=v0.0.6"
  ami                         = var.ami
  subnet_id                   = var.subnet_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  user_data                   = data.template_file.config_files.rendered
  vpc_security_group_ids      = [module.sg.sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.tfe_profile.name
  root_volume_size            = 100
  ec2_tags = {
    Name = "${var.owner}-instance"
  }
}

# IAM Role, Policy and Instance Profile 
resource "aws_iam_role" "tfe_role" {
  name               = "tfe_role"
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

resource "aws_iam_instance_profile" "tfe_profile" {
  name = "tfe_profile"
  role = aws_iam_role.tfe_role.name
}

resource "aws_iam_policy" "tfe_cloudwatch" {
  name   = "tfe_cloudwatch_policy"
  path   = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy_attach" {
  role       = aws_iam_role.tfe_role.name
  policy_arn = aws_iam_policy.tfe_cloudwatch.arn
}


# Load Balancer
resource "aws_lb" "flamarion_lb" {
  name               = "${var.owner}-lb"
  load_balancer_type = "application"
  security_groups    = [module.sg.sg_id]
  subnets            = var.subnets
  tags = {
    Name = "${var.owner}-lb"
  }
}

# LB Target groups
resource "aws_lb_target_group" "tfe_lb_tg_https" {
  name                 = "${var.owner}-tg-${var.https_port}"
  port                 = var.https_port
  protocol             = var.https_proto
  vpc_id               = var.vpc_id
  deregistration_delay = 60
  slow_start           = 300
  health_check {
    path                = "/_health_check"
    protocol            = var.https_proto
    matcher             = "200"
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_https_replicated" {
  name                 = "${var.owner}-tg-${var.replicated_port}"
  port                 = var.replicated_port
  protocol             = var.https_proto
  vpc_id               = var.vpc_id
  deregistration_delay = 60
  slow_start           = 180
  health_check {
    path                = "/dashboard"
    protocol            = var.https_proto
    matcher             = "200,301,302"
    interval            = 30
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "tfe_lb_tg_http" {
  name                 = "${var.owner}-tg-${var.http_port}"
  port                 = var.http_port
  protocol             = var.http_proto
  vpc_id               = var.vpc_id
  deregistration_delay = 60
  slow_start           = 180
  health_check {
    path                = "/"
    protocol            = var.http_proto
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
  protocol          = var.https_proto
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

resource "aws_lb_target_group_attachment" "http_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_http.arn
  target_id        = module.tfe_instance.instance_id[0]
  port             = var.http_port
}

resource "aws_lb_target_group_attachment" "https_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_https.arn
  target_id        = module.tfe_instance.instance_id[0]
  port             = var.https_port
}

resource "aws_lb_target_group_attachment" "replicated_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_https_replicated.arn
  target_id        = module.tfe_instance.instance_id[0]
  port             = var.replicated_port
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

