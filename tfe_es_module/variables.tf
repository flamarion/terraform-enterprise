variable "tag_prefix" {
  description = "Prefix for all tags and names"
  type        = string
  default     = "flamarion-tfe"
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

# Security Group Rules
variable "sg_lb_rules_cidr" {
  description = "Load Balancer Security Group Rules"
  type = map(object({
    description = string
    type        = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    protocol    = string
    sg_id       = string
  }))
  default = {
    ssh = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = -1
      sg_id       = "default"
    }
  }
}

variable "sg_db_rules_cidr" {
  description = "Load Balancer Security Group Rules"
  type = map(object({
    description = string
    type        = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    protocol    = string
    sg_id       = string
  }))
  default = {
    ssh = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = -1
      sg_id       = "default"
    }
  }
}

variable "sg_instance_rules_sgid" {
  description = "Security group rules"
  type = map(object({
    description = string
    type        = string
    from_port   = number
    to_port     = number
    source_sgid = string
    protocol    = string
    sg_id       = string
  }))
}

variable "sg_instance_rules_cidr" {
  description = "Load Balancer Security Group Rules"
  type = map(object({
    description = string
    type        = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    protocol    = string
    sg_id       = string
  }))
  default = {
    ssh = {
      description = "Terraform Cloud application via HTTP"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 0
      to_port     = 0
      protocol    = -1
      sg_id       = "default"
    }
  }
}

# Database
variable "db_name" {
  description = "Database Name"
  type        = string
  default     = "tfe"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "tfe"
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "tfe"
}

variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
  default     = "tfe"
}

variable "db_pass" {
  description = "Database user passworkd"
  type        = string
}

variable "db_instance_type" {
  description = "Database Instance type"
  type        = string
  default     = "db.t3.medium"
}

variable "az_list" {
  description = "Availabilyt Zone list"
  type        = list(string)
}

variable "db_sg_id_list" {
  description = "Security group list"
  type        = list(string)
}

variable "db_subnet_group" {
  description = "Database subnet group name"
  type        = string
  default     = "tfe-db-subnet-group"
}

# Instances
variable "image_id" {
  description = "AMI id"
  type        = string
  default     = "ami-0ca5b487ed9f8209f"
}

variable "instance_type" {
  description = "Compute Instance type"
  type        = string
  default     = "m5.large"
}

variable "key_name" {
  description = "SSH key name"
  type        = string
  default     = "default"
}

variable "instance_sg_list" {
  description = "Instance security groups"
  type        = list(string)
  default     = []
}

# TFE
variable "admin_password" {
  type    = string
  default = "SuperS3cret"
}

variable "rel_seq" {
  type    = string
  default = 0
}

# ASG
variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "vpc_zone_identifier" {
  description = "VPC Zones"
  type        = list(string)
}
# Load Balancer

variable "subnets" {
  description = "VPC Subnets"
  type        = list(string)
}

variable "lb_sg" {
  description = "Load Balancer security Group list"
  type        = list(string)
  default     = ["default"]
}

variable "http_port" {
  description = "HTTP Port"
  type        = number
  default     = 80
}

variable "http_proto" {
  description = "HTTP Protocol"
  type        = string
  default     = "HTTP"
}

variable "https_port" {
  description = "HTTPS Port"
  type        = number
  default     = 443
}

variable "https_proto" {
  description = "HTTPS Protocol"
  type        = string
  default     = "HTTPS"
}

variable "replicated_port" {
  description = "Replicated Port"
  type        = number
  default     = 8800
}

variable "replicated_proto" {
  description = "Replicated HTTP Protocol"
  type        = string
  default     = "HTTPS"
}

# DNS
variable "dns_record_name" {
  description = "DNS A Record alias prefix for the Load Balancer"
  type        = string
  default     = "tfe-es"
}

