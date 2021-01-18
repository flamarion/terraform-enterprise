# Load Balance Ports
variable "http_port" {
  type    = number
  default = 80
}

variable "http_proto" {
  type    = string
  default = "HTTP"
}

variable "https_port" {
  type    = number
  default = 443
}

variable "https_proto" {
  type    = string
  default = "HTTPS"
}

variable "replicated_port" {
  type    = number
  default = 8800
}

variable "replicated_proto" {
  type    = string
  default = "HTTPS"
}

# Instances
variable "cloud_pub" {
  description = "SSH Public key pair"
  type        = string
}

# App variables

variable "dns_record_name" {
  type    = string
  default = "flamarion-demo"
}

variable "admin_password" {
  type    = string
  default = "SuperS3cret"
}

variable "rel_seq" {
  type    = number
  default = 0
}

# General
variable "owner" {
  description = "Prefix for all tags and names"
  type        = string
  default     = "fj"
}

