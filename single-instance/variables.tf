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
