variable "instance_count" {
  description = ""
  type = number
  default = 1
}
variable "ami_id" {
  description = ""
  type = string
  default = "ami-01f629e0600d93cef"
}
variable "subnet_id" {
  description = ""
  type = string
  default = ""
}
variable "instance_type" {
  description = ""
  type = string
  default = "m5.large"
}
variable "key_name" {
  description = ""
  type = string
  default = ""
}
variable "user_data" {
  description = ""
  type = string
  default = ""
}
variable "vpc_security_group_ids" {
  description = ""
  type = list(string)
  default = []
}
variable "root_volume_size" {
  description = ""
  type = number
  default = 100
}
variable "instance_tags" {
  description = ""
  type = map(string)
  default = {}
}

variable "tag_prefix" {
  description = ""
  type = string
  default = ""
}