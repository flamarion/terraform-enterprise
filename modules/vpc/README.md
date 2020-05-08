# VPC Modules

This module is intended to create a VPC with the following components.

* VPC
* Public Subnets
* Private Subnets
* Database Subnets
* Database Subnet Group
* Internet Gateway
* Nat Gateway 
* Route tables
* Routes 
  + private subnets -> nat gateway
  + database subnets -> nat gateway
  + public subnets -> internet gateway

Only one Nat Gateway and EIP will be created in order to save costs.

If you need more detailed configuration inside a VPC I recommend you use the official terraform module for AWS VPC

https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws

## Input Variables

|Name|Type|Mandatory|Default Value|Description|
|----|----|---------|-------------|-----------|
|az|list(string)|yes|["eu-central-1a"]|Availability Zone List|
|cidr_block|string|yes|"10.0.0.0/16"|Network address in CIDR format|
|create_db_subnet_group|bool|no|false|Create database subnet group with the database subnets|
|database_subnet_group_tags|map(string|no|{}|Database subnet group tags, will be merged with default tags|
|database_subnet_tags|map(string)|no|{}|Map of tags for the database subnets, will be merged with default tags|
|database_subnets|list(string)|no|[]|List of database subnets|
|eip_tags|map(string)|no|{}|Map of tags for the EIP, will be merged with default tags|
|enable_dns_hostnames|bool|no|true|Enable hostname support in the VPC|
|enable_dns_support|bool|no|true|Enable DNS support in the VPC|
|enable_nat_gateway|bool|no|false|Enable nat gateway for private subnet|
|igw_tags|map(string)|no|{}|Map of tags for the Internet Gateway, will be merged with default tags|
|map_public_ip|bool|no|false|Map public ip for instances in public subnets|
|nat_gw_tags|map(string)|no|{}|Map of tags for the Nat Gateway, will be merged with default tags|
|private_subnet_tags|map(string)|no|{}|Map of tags for the private subnets, will be merged with default tags|
|private_subnets|list(string)|no|["10.0.1.0/24"]|List of private subnets|
|public_subnet_tags|map(string)|no|{}|Map of tags for the public subnets, will be merged with default tags|
|public_subnets|list(string)|no|["10.0.0.0/24"]|List of public subnets|
|tag_prefix|string|no|""|String which will prefix all tags|
|vpc_tags|map(string)|no|{}|Map of tags for the VPC, will be merged with default tags|

## Outputs

The outputs available are the following

|Name|Description|
|----|-----------|
|az|availability zone list|
|database_subnets|database subnets CIDR list|
|database_subnets_id|database subnet id list|
|db_subnet_group|database subnet group id/name|
|private_subnets|private subnets CIDR list|
|private_subnets_id|private subnet id list|
|public_subnets|public subnets CIDR list|
|public_subnets_id|public subnet id list|
|vpc_id|VPC id|

## Example

Create the file `main.tf` and `outputs.tf` in the same directory.

`main.tf`

```
provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.59"
}

terraform {
  required_version = "~> 0.12"
}

module "tfe_vpc" {

  source = "../../../modules/vpc"

  # VPC
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnets
  az                     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets         = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets        = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets       = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
  create_db_subnet_group = true
  map_public_ip          = true
  enable_nat_gateway     = true
  tag_prefix             = "flamarion-tfe"
}

```

`outputs.tf`

```
output "vpc_id" {
  value = module.tfe_vpc.vpc_id
}

output "public_subnets" {
  value = module.tfe_vpc.public_subnets
}

output "public_subnets_id" {
  value = module.tfe_vpc.public_subnets_id
}

output "private_subnets" {
  value = module.tfe_vpc.private_subnets
}

output "private_subnets_id" {
  value = module.tfe_vpc.private_subnets_id
}

output "database_subnets" {
  value = module.tfe_vpc.database_subnets
}

output "database_subnets_id" {
  value = module.tfe_vpc.database_subnets_id
}

output "db_subnet_group" {
  value = module.tfe_vpc.db_subnet_group
}

output "az" {
  value = module.tfe_vpc.az
}
```

With the files above created in the same directory, fix the source path to where the module is and run the commands bellow.

`terraform init`

`terraform plan -out vpc.tfplan`
 
`terraform apply vpc.tfplan`

The output should be this:

```
az = [
  "eu-central-1a",
  "eu-central-1b",
  "eu-central-1c",
]
database_subnets = [
  "10.0.6.0/24",
  "10.0.7.0/24",
  "10.0.8.0/24",
]
database_subnets_id = [
  "subnet-0388c15a4d0e887b2",
  "subnet-02e7e3c7111368134",
  "subnet-02689863c8c8f946d",
]
db_subnet_group = [
  "flamarion-tfe-db-subnet-group",
]
private_subnets = [
  "10.0.3.0/24",
  "10.0.4.0/24",
  "10.0.5.0/24",
]
private_subnets_id = [
  "subnet-066718db4acc5a9d1",
  "subnet-0f01cd61651dcface",
  "subnet-04e73964c28f61739",
]
public_subnets = [
  "10.0.0.0/24",
  "10.0.1.0/24",
  "10.0.2.0/24",
]
public_subnets_id = [
  "subnet-0583f7b37ed904e0f",
  "subnet-067a7beeba0f09fac",
  "subnet-0427be6ceaae2a5b6",
]
vpc_id = vpc-0576acb5680c0264c
```
