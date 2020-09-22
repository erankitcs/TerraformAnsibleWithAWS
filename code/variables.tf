variable "profile" {
  type    = string
  default = "terraformuser"
}

variable "region-master" {
  type    = string
  default = "us-east-1"
}

variable "region-worker" {
  type    = string
  default = "us-west-2"
}

variable "external-ip" {
  type    = string
  default = "0.0.0.0/0"
}

variable "instance-type" {
  type    = string
  default = "t3.micro"
}
#How many Jenkins workers to spin up
variable "workers-count" {
  type    = number
  default = 1
}

#Add the variable webserver-port to variables.tf
variable "webserver-port" {
  type    = number
  default = 8080
}

variable "dns-name" {
  type    = string
  default = "techenvision.net."
}