variable "region" {
  type = "string"
  description = "Chosen region. As a newbie, only N.Virginia is allowed for me"
  default = "us-east-1"
}

variable "availability-zone1" {
  type = "string"
  default = "us-east-1a"
}

variable "availability-zone2" {
  type = "string"
  default = "us-east-1b"
}

variable "frontend-ami-id" {
	type = "string"
  	default = "ami-04681a1dbd79675a5"
}

variable "backend-ami-id" {
	type = "string"
  	default = "ami-04681a1dbd79675a5"
}

variable "bastion-ami-id" {
	type = "string"
  	default = "ami-04681a1dbd79675a5"
}

variable "PUBLIC_KEY_PATH" {
  type = "string"
  default = "../../simple.pub"
}