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

variable "rel_seq" {
  type = number
  default = 0
}