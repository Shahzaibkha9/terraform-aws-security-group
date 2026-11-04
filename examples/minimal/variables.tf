variable "name" {
  description = "Name of the security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group lives."
  type        = string
}
