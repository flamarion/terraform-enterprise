variable "db_engine" {
  description = "Postgresql, Mysql, Aurora"
  type        = string
  default     = "aurora-postgresql"
}

variable "cluster_identifier" {
  description = "String to identify the DB"
  type        = string
  default     = "tfe"
}

variable "db_name" {
  description = "DB Name"
  type        = string
  default     = "tfe"
}

variable "db_pass" {
  description = "DB Master Password"
  type        = string
  default     = "SuperS3cret"
}

variable "db_user" {
  description = "DB Master Username"
  type        = string
  default     = "tfe"
}

variable "skip_final_snapshot" {
  description = "Before delete skip final snapshot"
  type        = bool
  default     = true
}

variable "az_list" {
  description = "List of availability zones"
  type        = list(string)
}

variable "sg_id_list" {
  description = "List of security groups"
  type        = list(string)
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = true
}

variable "db_subnet_group" {
  description = "DB Subnet Group Name"
  type        = string
}

variable "db_tags" {
  description = "Map of db tags"
  type        = map(string)
  default = {
    Name = "tfe"
  }
}

variable "instance_identifier" {
  description = "String to identify the DB Instance"
  type        = string
  default     = "tfe"
}

variable "instance_type" {
  description = "Kind of instancd to deploy the instance"
  type        = string
  default     = "db.t3.medium"
}

variable "public" {
  description = "Publicly accessible"
  type        = bool
  default     = false
}