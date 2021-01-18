# Script to install TFE
data "template_file" "config_files" {
  template = file("${path.module}/templates/userdata.tpl")
  vars = {
    admin_password = var.admin_password
    rel_seq        = var.rel_seq
    lb_fqdn        = aws_route53_record.alias_record.fqdn
  }
}

# Instance configuration
module "tfe_instance" {
  source                      = "github.com/flamarion/terraform-aws-ec2?ref=v0.0.7"
  ami                         = "ami-0ca5b487ed9f8209f"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnets_id[0]
  instance_type               = "m5.large"
  key_name                    = aws_key_pair.tfe_key.key_name
  user_data                   = data.template_file.config_files.rendered
  vpc_security_group_ids      = [module.sg.sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.tfe_profile.name
  root_volume_size            = 100
  ec2_tags = {
    Name = "${var.owner}-tfe-demo-instance"
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
