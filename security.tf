# Security Group
module "sg" {
  source      = "github.com/flamarion/terraform-aws-sg?ref=v0.0.5"
  name        = "${var.owner}-tfe-demo-sg"
  description = "Security Group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  sg_tags = {
    Name = "${var.owner}-tfe-demo-sg"
  }

  sg_rules_cidr = {
    ssh = {
      description       = "SSH"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = 22
      to_port           = 22
      protocol          = "tcp"
      security_group_id = module.sg.sg_id
    },
    https = {
      description       = "Terraform Cloud application via HTTPS"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = var.https_port
      to_port           = var.https_port
      protocol          = "tcp"
      security_group_id = module.sg.sg_id
    },
    replicated = {
      description       = "Replicated dashboard"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = var.replicated_port
      to_port           = var.replicated_port
      protocol          = "tcp"
      security_group_id = module.sg.sg_id
    },
    outbound = {
      description       = "Allow all outbound"
      type              = "egress"
      cidr_blocks       = ["0.0.0.0/0"]
      to_port           = 0
      protocol          = "-1"
      from_port         = 0
      security_group_id = module.sg.sg_id
    }
  }
}
