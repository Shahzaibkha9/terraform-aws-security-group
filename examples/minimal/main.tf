module "sg" {
  source = "../.."

  name   = var.name
  vpc_id = var.vpc_id

  # One ingress rule, no egress. Deny-all egress is the module default.
  ingress_rules = {
    https_from_vpc = {
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.0.0/16"
      description = "Allow HTTPS from the VPC CIDR"
    }
  }
}
