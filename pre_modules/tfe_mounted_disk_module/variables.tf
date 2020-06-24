variable "tag_prefix" {
  description = "Prefix for all tags and names"
  type        = string
  default     = "flamarion-tfe"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "image_id" {
  description = "AMI id"
  type        = string
  default     = "ami-01f629e0600d93cef"
}

# 22: To access the instance via SSH from your computer. SSH access to the instance is required for administration and debugging.
# 80: To access the Terraform Cloud application via HTTP. This port redirects to port 443 for HTTPS.
# 443: To access the Terraform Cloud application via HTTPS.

variable "http_port" {
  description = "HTTP Port"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS Port"
  type        = number
  default     = 443
}

variable "replicated_port" {
  description = "Replicated Port"
  type        = number
  default     = 8800
}

variable "ssh_port" {
  description = "SSH Port"
  type        = number
  default     = 22
}

