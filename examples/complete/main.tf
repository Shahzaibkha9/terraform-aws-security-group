module "sg" {
  source = "../.."

  name        = var.name
  description = "Application security group - full example demonstrating all four rule source types"
  vpc_id      = var.vpc_id

  # Four rules exercising each source type.
  ingress_rules = {
    https_corp = {
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = var.vpc_cidr
      description = "HTTPS from VPC CIDR"
    }
    https_ipv6 = {
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv6   = "::/0"
      description = "HTTPS from any IPv6 origin"
      tags        = { Scope = "public" }
    }
    from_app_sg = {
      ip_protocol                  = "tcp"
      from_port                    = 8080
      to_port                      = 8080
      referenced_security_group_id = var.app_security_group_id
      description                  = "App traffic from app SG"
    }
  }

  egress_rules = {
    to_s3 = {
      ip_protocol    = "tcp"
      from_port      = 443
      to_port        = 443
      prefix_list_id = var.s3_prefix_list_id
      description    = "HTTPS to the regional S3 prefix list"
    }
    to_vpc = {
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
      description = "All protocols within VPC CIDR"
    }
  }

  tags = {
    Environment = "production"
    Owner       = "platform"
  }
}
