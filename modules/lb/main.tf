resource "aws_lb" "lb" {
  name               = var.lb_name
  load_balancer_type = var.lb_type
  security_groups    = var.lb_sg
  subnets            = var.lb_subnets
  tags               = var.lb_tags
}

resource "aws_lb_target_group" "tg" {
  count                = lenght(var.target_groups)
  name                 = var.tg_name
  port                 = var.tg_port
  protocol             = var.tg_protocol
  vpc_id               = var.tg_vpc_id
  deregistration_delay = var.tg_dereg_delay
  slow_start           = var.tg_slow_start
  health_check {
    path                = var.path
    protocol            = var.tg_protocol
    matcher             = var.matcer
    interval            = var.interval
    timeout             = var.timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }
  tags                  = var.tg_tags
}


resource "aws_lb_listener" "ln" {
  count = lenght(var.https_listneres)
  load_balancer_arn = aws_lb.lb.arn
  port              = var.ln_port
  protocol          = var.tg_protocol
  certificate_arn   = var.ln_cert
  ssl_policy        = var.ln_ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[count.index].arn
  }
}
