variable "az" {
  description = ""
  type        = list(string)
  default     = []
}

variable "cidr_block" {
  description = ""
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_hostnames" {
  description = ""
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = ""
  type        = bool
  default     = true
}

variable "tag_prefix" {
  description = ""
  type        = string
  default     = ""
}

variable "vpc_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "eip_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "public_subnets" {
  description = ""
  type        = list(string)
  default     = []
}

variable "map_public_ip" {
  description = ""
  type        = bool
  default     = false
}

variable "public_subnet_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "private_subnets" {
  description = ""
  type        = list(string)
  default     = []
}

variable "private_subnet_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "database_subnets" {
  description = ""
  type        = list(string)
  default     = []
}

variable "database_subnet_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "create_db_subnet_group" {
  description = ""
  type        = bool
  default     = false
}

variable "database_subnet_group_tags" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = ""
  type        = bool
  default     = false
}
variable "nat_gw_tags" {
  description = ""
  type        = map(string)
  default     = {}
}
variable "igw_tags" {
  description = ""
  type        = map(string)
  default     = {}
}
