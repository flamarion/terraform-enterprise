terraform {
  required_providers {
    aws      = "~> 2.59"
    template = "~> 2.1"
  }
  required_version = "~> 0.12"
}


# Security Group
module "tfe_sg" {
  source  = "../modules/sg"
  sg_name = "${var.tag_prefix}-sg"
  sg_desc = "Security Group"
  vpc_id  = var.vpc_id
  tags = {
    Name = "${var.tag_prefix}-sg"
  }

  sg_rules_cidr = var.sg_rules_cidr
}

#EBS Volume format and mount
data "template_file" "alias_nvme" {
  template = "${file("${path.module}/templates/ebs_alias.sh.tpl")}"
}

data "template_file" "attach_nvme" {
  template = "${file("${path.module}/templates/ebs_mount.sh.tpl")}"

  vars = {
    volume_name = var.ebs_device_name
    mount_point = var.ebs_mount_point
    file_system = var.ebs_file_system
  }
}

# Script to install TFE
data "template_file" "tfe_config" {
  template = file("${path.module}/templates/tfe_config.sh.tpl")
  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    lb_fqdn        = aws_route53_record.flamarion.fqdn
    tfe_mount_point = var.ebs_mount_point
  }
}

data "template_cloudinit_config" "final_config" {

  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.alias_nvme.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.attach_nvme.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.tfe_config.rendered
  }

}


# Instance configuration
resource "aws_instance" "tfe_instance" {
  ami                    = var.ami_id
  subnet_id              = var.subnet_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = data.template_cloudinit_config.final_config.rendered
  vpc_security_group_ids = [module.tfe_sg.sg_id]

  root_block_device {
    volume_size = var.root_volume_size
  }
  tags = merge(
    var.instance_tags,
    {
      Name = "${var.tag_prefix}-instance"
    }
  )
}

# EBS volume
resource "aws_ebs_volume" "tfe_data" {
  availability_zone = aws_instance.tfe_instance.availability_zone
  size              = var.ebs_volume_size
  type              = "gp2"
  tags = {
    Name = "${var.tag_prefix}-ebs-volume"
  }
}

resource "aws_volume_attachment" "tfe_data_attachment" {
  device_name = var.ebs_device_name
  volume_id   = aws_ebs_volume.tfe_data.id
  instance_id = aws_instance.tfe_instance.id
}


# Load Balancer
resource "aws_lb" "flamarion_lb" {
  name               = "${var.tag_prefix}-lb"
  load_balancer_type = "application"
  security_groups    = [module.tfe_sg.sg_id]
  subnets            = var.subnets
  tags = {
    Name = "${var.tag_prefix}-lb"
  }
}

# LB Target groups
resource "aws_lb_target_group" "tfe_lb_tg_https" {
  name                 = "${var.tag_prefix}-tg-${var.https_port}"
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
  name                 = "${var.tag_prefix}-tg-${var.replicated_port}"
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
  name                 = "${var.tag_prefix}-tg-${var.http_port}"
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
  name    = "${var.dns_record_name}.hashicorp-success.com"
  type    = "A"
  alias {
    name                   = aws_lb.flamarion_lb.dns_name
    zone_id                = aws_lb.flamarion_lb.zone_id
    evaluate_target_health = true
  }
}

