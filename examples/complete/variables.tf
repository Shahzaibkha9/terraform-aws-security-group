variable "name" {
  description = "Name of the security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group lives."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR, used to scope ingress and egress."
  type        = string
}

variable "app_security_group_id" {
  description = "Pre-existing application security group ID that this SG allows traffic from and to."
  type        = string
}

variable "s3_prefix_list_id" {
  description = "AWS-managed prefix list ID for S3 in this region (e.g. pl-xxxxxxxx), used to allow egress to S3."
  type        = string
}
