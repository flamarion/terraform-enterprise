# AWS EC2 Instance Module

This module is intended to create a Single or Multiple AWS EC2 Instances within a VPC.

This module doesn't work to create instances in default VPC

If you need more detailed configuration for a EC2 Instances I recommend you use the official terraform module for AWS EC2

https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/1.8.0

## Input Variables

|Name|Type|Mandatory|Default Value|Description|
|----|----|---------|-------------|-----------|
|instance_count|number|no|1|Number of EC2 instances created|
|ami_id|string|yes|ami-01f629e0600d93cef|AMI used to build the instance|
|subnet_id|string|yes|""|Subnet ID withing a VPC|
|instance_type|string|yes|m5.large|EC2 Instance flavor|
|key_name|string|yes|""|SSH Public key used to connect to the instance|
|user_data|string|no|""|Script or Template to be injected via cloud-init|
|vpc_security_group_ids|list(string)|[]|Security Group list|
|root_volume_size|number|no|100|Root disk size|
|instance_tag|map(string)|no|{}|Map of tags in formate key value|
|tag_prefix|string|no|""|String to prefix default tags and resource name|


## Outputs

The outputs available are the following

|Name|Description|
|----|-----------|
|instance_id| Instance ID|
|public_ip|Instance Public IP if used in the public subnet|
|public_dns|Instance Public FQDN|


## Example

Create the file `main.tf` and `outputs.tf` in the same directory.

`main.tf`

```
module "tfe_instance" {
  source = "../../../modules/ec2"
  instance_count = 1
  ami_id = var.image_id
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_ids[0]
  instance_type = "m5.large"
  user_data = data.template_file.config_files.rendered
  root_volume_size = 100
}

```

`outputs.tf`

```
output "instance_id" {
  value = module.tfe_instance.*.intance_id
}

output "public_ip" {
  value = module.tfe_instance.*.public_ip
}

output "public_dns" {
  value = module.tfe_instance.*.public_dns
}
```

With the files above created in the same directory, fix the source path to where the module is and run the commands bellow.

`terraform init`

`terraform plan -out vpc.tfplan`
 
`terraform apply vpc.tfplan`
