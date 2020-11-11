# Global Variables
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "owner" {
  description = "Prefix for all tags and names"
  type        = string
  default     = "flamarion-tfe"
}

# VPC variables
variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "subnets" {
  description = "VPC Subnets"
  type        = list(string)
}

# Instance Variables
variable "instance_count" {
  description = "How many instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "AWS Instance Type"
  type        = string
  default     = "m5.large"
}

variable "ami" {
  description = "AMI id"
  type        = string
  default     = "ami-01f629e0600d93cef"
}

variable "key_name" {
  description = "SSH Key name"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size"
  type        = number
  default     = 40
}

variable "instance_tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}


# Load Balance Ports
variable "http_port" {
  type    = number
  default = 80
}

variable "https_port" {
  type    = number
  default = 443
}

variable "replicated_port" {
  type    = number
  default = 8800
}

variable "http_proto" {
  type    = string
  default = "HTTP"
}

variable "https_proto" {
  type    = string
  default = "HTTPS"
}

# Security Group Rules
variable "sg_rules_cidr" {
  description = "Security group rules"
  type = map(object({
    description       = string
    type              = string
    from_port         = number
    to_port           = number
    cidr_blocks       = list(string)
    protocol          = string
    security_group_id = string
  }))
  default = {}
}

# App variables

variable "dns_record_name" {
  type    = string
  default = "tfe-demo"
}

variable "admin_password" {
  type    = string
  default = "SuperS3cret"
}

variable "rel_seq" {
  type    = number
  default = 0
}
