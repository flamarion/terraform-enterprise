variable "http_port" {
  type = number
  default = 80
}

variable "http_proto" {
  type = string
  default = "HTTP"
}

variable "https_port" {
  type = number
  default = 443
}

variable "https_proto" {
  type = string
  default = "HTTPS"
}

variable "replicated_port" {
  type = number
  default = 8800
}

variable "replicated_proto" {
  type = string
  default = "HTTPS"
}