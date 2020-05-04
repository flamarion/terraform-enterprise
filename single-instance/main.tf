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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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
  public_key = file("~/.ssh/cloud.pub")
}

resource "aws_security_group" "tfe_sg" {
  name        = "${var.tag_prefix}-sg"
  description = "Security Group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags = {
    Name = "${var.tag_prefix}-sg"
  }
}

# Ingress
# 22: To access the instance via SSH from your computer. SSH access to the instance is required for administration and debugging.
# 80: To access the Terraform Cloud application via HTTP. This port redirects to port 443 for HTTPS.
# 443: To access the Terraform Cloud application via HTTPS.
# 8800: To access the installer dashboard.
# 9870-9880 (inclusive): For internal communication on the host and its subnet; not publicly accessible.
# 23000-23100 (inclusive): For internal communication on the host and its subnet; not publicly accessible.

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
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_https" {
  description       = "Terraform Cloud application via HTTPS"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_installer" {
  description       = "access the installer dashboard"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 8800
  to_port           = 8800
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_internal_1" {
  description       = "TFE Internal Communication"
  type              = "ingress"
  cidr_blocks       = data.terraform_remote_state.vpc.outputs.subnets
  from_port         = 9870
  to_port           = 9880
  protocol          = "tcp"
  security_group_id = aws_security_group.tfe_sg.id
}

resource "aws_security_group_rule" "tfe_internal_2" {
  description       = "TFE Internal Communication"
  type              = "ingress"
  cidr_blocks       = data.terraform_remote_state.vpc.outputs.subnets
  from_port         = 23000
  to_port           = 23100
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


resource "aws_instance" "tfe" {
  ami                    = data.aws_ami.ubuntu.id
  subnet_id              = data.terraform_remote_state.vpc.outputs.subnet_ids[0]
  instance_type          = "m5.large"
  key_name               = aws_key_pair.tfe_key.key_name
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]
  root_block_device {
    volume_size = 100
  }

  provisioner "file" {
    source      = "conf/settings.json"
    destination = "/var/tmp/settings.json"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/cloud")
      host        = self.public_dns
    }
  }

  provisioner "file" {
    source      = "conf/replicated.conf"
    destination = "/var/tmp/replicated.conf"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/cloud")
      host        = self.public_dns
    }
  }

  # provisioner "file" {
  #   source      = "conf/hashicorp-emea-support.rli"
  #   destination = "/var/tmp/license.rli"
  #   connection {
  #     type        = "ssh"
  #     user        = "ubuntu"
  #     private_key = file("~/.ssh/cloud")
  #     host        = self.public_dns
  #   }
  # }

  provisioner "file" {
    source      = "conf/certs/localhost.crt"
    destination = "/var/tmp/localhost.crt"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/cloud")
      host        = self.public_dns
    }
  }

    provisioner "file" {
    source      = "conf/certs/localhost.key"
    destination = "/var/tmp/localhost.key"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/cloud")
      host        = self.public_dns
    }
  }


  tags = merge(var.special_tags, { Name = "${var.tag_prefix}-instance" })

}

# resource "null_resource" "tfe_bootstrap" {

#   triggers = {
#     instance = aws_route53_record.flamarion.id
#   }

#   provisioner "remote-exec" {
#     inline = ["sudo mv /var/tmp/settings.json /var/tmp/replicated.conf /var/tmp/license.rli /var/tmp/localhost.crt /var/tmp/localhost.key /etc/",
#       "sudo chmod 644 /etc/replicated.conf /etc/settings.conf",
#       "curl -o install.sh https://install.terraform.io/ptfe/stable",
#       "sudo bash ./install.sh no-proxy private-address=${aws_instance.tfe.private_ip} public-address=${aws_instance.tfe.public_ip}",
#       "while ! curl -ksfS --connect-timeout 5 https://${aws_route53_record.flamarion.fqdn}/_health_check; do sleep 5; done"
#     ]
#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       private_key = file("~/.ssh/cloud")
#       host        = aws_route53_record.flamarion.fqdn
#     }
#   }
# }


resource "null_resource" "tfe_bootstrap" {

  triggers = {
    instance = aws_route53_record.flamarion.id
  }

  provisioner "remote-exec" {
    inline = ["sudo mv /var/tmp/settings.json /var/tmp/replicated.conf /var/tmp/localhost.crt /var/tmp/localhost.key /etc/",
      "sudo chmod 644 /etc/replicated.conf /etc/settings.conf",
      "curl -o install.sh https://install.terraform.io/ptfe/stable",
      "sudo bash ./install.sh no-proxy private-address=${aws_instance.tfe.private_ip} public-address=${aws_instance.tfe.public_ip}",
      "while ! curl -ksfS --connect-timeout 5 https://${aws_route53_record.flamarion.fqdn}/_health_check; do sleep 5; done"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/cloud")
      host        = aws_route53_record.flamarion.fqdn
    }
  }
}



data "aws_route53_zone" "selected" {
  name = "hashicorp-success.com."
}

resource "aws_route53_record" "flamarion" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "flamarion-single.hashicorp-success.com"
  type    = "CNAME"
  ttl     = "5"
  records = [aws_instance.tfe.public_dns]
}

