variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "tag_prefix" {
  description = "Prefix for all tags and names"
  type        = string
  default     = "flamarion-tfe"
}

variable "special_tags" {
  type = map(string)
  default = {
    "test:author" = "some value"
  }
}

variable "image_id" {
  description = "AMI id"
  type        = string
  default     = "ami-01f629e0600d93cef"
}

variable "http_port" {
  type = number
  default = 80
}

variable "https_port" {
  type = number
  default = 443
}

variable "replicated_port" {
  type = number
  default = 8800
}

variable "tfe_admin_password" {
  type = string
}