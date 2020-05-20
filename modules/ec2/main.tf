terraform {
  required_version = "~> 0.12"

  required_providers {
    aws = "~> 2.59"
  }
}


resource "aws_instance" "tfe_instance" {
  count                  = var.instance_count
  ami                    = var.ami_id
  subnet_id              = var.subnet_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = var.user_data
  vpc_security_group_ids = var.vpc_security_group_ids

  root_block_device {
    volume_size = var.root_volume_size
  }
  tags = merge(
    var.instance_tags,
    {
      Name = "${var.tag_prefix}-public-subnet"
    }
  )
  
  
}
