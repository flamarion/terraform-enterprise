# Load Balancer
resource "aws_lb" "lb" {
  name               = "${var.owner}-tfe-es-lb"
  load_balancer_type = "application"
  security_groups    = [module.sg.sg_id]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnets_id
  tags = {
    Name = "${var.owner}-tfe-demo-lb"
  }
}

# LB Target groups
resource "aws_lb_target_group" "tfe_lb_tg_https" {
  name                 = "${var.owner}-tg-demo-${var.https_port}"
  port                 = var.https_port
  protocol             = var.https_proto
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
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
  name                 = "${var.owner}-tg-demo-${var.replicated_port}"
  port                 = var.replicated_port
  protocol             = var.https_proto
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
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
  name                 = "${var.owner}-tg-demo-${var.http_port}"
  port                 = var.http_port
  protocol             = var.http_proto
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
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
  load_balancer_arn = aws_lb.lb.arn
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
  load_balancer_arn = aws_lb.lb.arn
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
  load_balancer_arn = aws_lb.lb.arn
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
    host_header {
      values = [aws_route53_record.alias_record.fqdn]
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
    host_header {
      values = [aws_route53_record.alias_record.fqdn]
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
    host_header {
      values = [aws_route53_record.alias_record.fqdn]
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
