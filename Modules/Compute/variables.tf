variable "vpc_id" {
  type = string
  description = "vpc_id from the network module"
}

variable "subnet_1_id" {
  type = string
  description = "application subnet_id"
}

variable "subnet_2_id" {
  type = string
  description = "management subnet_id"
}

variable "subnet_3_id" {
  type = string
  description = "backend subnet_id"
}

variable "my_ip_cidr" {
  type = string
  description = "local ip in cidr format"
}

variable "image_id" {
  type = string
  description = "ami to use for ec2 instances"
}

variable "instance_type" {
  type  = string
  description = "ec2 instance type"
}

variable "iam_instance_profile_name" {
  type = string
  description = "name of IAM instance profile"
}
