provider "aws" {
  region  = var.region
  version = "~> 2.59"
}


terraform {
  required_version = "~> 0.12"
  backend "s3" {

    bucket = "flamarion-hashicorp"
    key    = "tfstate/tfe-single-instance.tfstate"
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
  key_name   = "flamarion-tfe"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCWTvOFNdwL7X3sVa3trlSYyQCZ1mAbTSMa7Z3V+0px4NU24ZcI93yh5UTAZjhHMh95hoc7069O/3Yj4V1v92oI+UdNF8ZcBY9BwtuzIlAVB7RLAyCzMdO91Jg4OMtUcCeM5beVKqW6Qp1AywbNCcbcfRBnTcfuRkZswjHLlMj+CsBaU23QiVE8tbARDCOTXCwErbxhcwmOnKE1dnhEZkslqFxsTYUZIQgj6ePB5cCBUGLb2n0PQ5NmVo3+xBsEVC3OaX1xjf0WPzF6+ppSEa2qm1BqqbMi9tMrObVZn37/Zu75OizSJrGrgRz3YTJixebS7nA309jDuJMzWj3HA/m3RWdtRVCnBIqpG75X4uzVg9TFRaNbF+tN37Lrdlp8tWKW4JeWlO9hNtPkZVYqXVqfuWMaiY+BZoVmvw4sPgAZRufFMj1gNxiYTCoOlVzyIZJZvUxum2dIVm/GxsZylP9N4WpZOuyb4UTuyOlMnXONFAgLD1z1lWx1+0cG18T+5PmeIzutYVE5tIPDc+dEW2ZvJKHDqAhk7JjG60UvbcdjXBhCDDEM3Crf0sptwcsfLavhF3aSy6d4NKDRL4LtC908Vrnz3zwuO0XQ5ZJyJzYh2U6VqTQQfcdLuQ4qMr0TIqv1f29+VPy7b9aXVQrQKeCs4aviTzI/SpwADm+1Swkm9w== flamarion@arvore"
}

resource "aws_security_group" "tfe_sg" {
  name        = "${var.tag_prefix}-sg"
  description = "Security Group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags = {
    Name = "${var.tag_prefix}-sg"
  }
}

resource "aws_security_group_rule" "tfe_ssh" {
  description       = "Allow SSH"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_http" {
  description       = "Terraform Cloud application via HTTP"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = var.http_port
  to_port           = var.http_port
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_https" {
  description       = "Terraform Cloud application via HTTPS"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = var.https_port
  to_port           = var.https_port
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_replicated_https" {
  description       = "Replicated Dashboard"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = var.replicated_port
  to_port           = var.replicated_port
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}



resource "aws_security_group_rule" "tfe_outbound" {
  description       = "Outbound traffic is allowed"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = -1
  security_group_id = aws_security_group.tfe_sg.id
}


data "template_file" "config_files" {
  template = file("templates/userdata.tpl")
  vars = {
    admin_password = var.tfe_admin_password
  }
}


resource "aws_instance" "tfe_instance" {
  ami                    = var.image_id
  subnet_id              = data.terraform_remote_state.vpc.outputs.subnet_ids[0]
  instance_type          = "m5.large"
  key_name               = aws_key_pair.tfe_key.key_name
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]
  user_data              = data.template_file.config_files.rendered
  root_block_device {
    volume_size = 100
  }

  tags = merge(var.special_tags, { Name = "${var.tag_prefix}-instance" })

}

resource "aws_lb" "flamarion_lb" {
  name               = "${var.tag_prefix}-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tfe_sg.id]
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

resource "aws_lb_target_group_attachment" "http_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_http.arn
  target_id        = aws_instance.tfe_instance.id
  port             = var.http_port
}

resource "aws_lb_target_group_attachment" "https_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_https.arn
  target_id        = aws_instance.tfe_instance.id
  port             = var.https_port
}

resource "aws_lb_target_group_attachment" "replicated_port" {
  target_group_arn = aws_lb_target_group.tfe_lb_tg_https_replicated.arn
  target_id        = aws_instance.tfe_instance.id
  port             = var.replicated_port
}



# Route53 DNS Record

data "aws_route53_zone" "selected" {
  name = "hashicorp-success.com."
}

resource "aws_route53_record" "flamarion" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "flamarion-demo.hashicorp-success.com"
  type    = "A"
  alias {
    name                   = aws_lb.flamarion_lb.dns_name
    zone_id                = aws_lb.flamarion_lb.zone_id
    evaluate_target_health = true
  }
}

