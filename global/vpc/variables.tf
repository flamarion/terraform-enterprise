variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}


variable "tags" {
  description = "Tag List"
  type        = map(string)
  default     = {}
}

variable "tag_prefix" {
  description = "Common prefix for all tags"
  type        = string
  default     = "flamarion-tfe"
}
