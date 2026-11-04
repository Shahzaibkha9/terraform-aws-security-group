# Tests for variable validations and lifecycle preconditions.
# Uses the mock provider so no AWS credentials are required.
# All runs use `command = plan` since the mock provider cannot generate
# valid ARNs for apply.

mock_provider "aws" {}

# ── name validation ──────────────────────────────────────────────────────────

run "name_with_invalid_characters_is_rejected" {
  command         = plan
  expect_failures = [var.name]

  variables {
    name   = "bad%name?"
    vpc_id = "vpc-00000000"
  }
}

run "name_with_aws_allowed_punctuation_is_accepted" {
  command = plan

  variables {
    name   = "web tier & app!"
    vpc_id = "vpc-00000000"
  }

  assert {
    condition     = aws_security_group.this[0].name_prefix == "web tier & app!-"
    error_message = "AWS allows spaces, '&' and '!' in VPC security group names; the module should accept them."
  }
}

run "name_too_long_is_rejected" {
  command         = plan
  expect_failures = [var.name]

  variables {
    name   = join("", [for _ in range(229) : "a"])
    vpc_id = "vpc-00000000"
  }
}

run "name_starting_with_sg_prefix_is_rejected" {
  command         = plan
  expect_failures = [var.name]

  variables {
    name   = "sg-web"
    vpc_id = "vpc-00000000"
  }
}

run "name_starting_with_mixed_case_sg_prefix_is_rejected" {
  command         = plan
  expect_failures = [var.name]

  variables {
    name   = "SG-web"
    vpc_id = "vpc-00000000"
  }
}

# ── description validation ───────────────────────────────────────────────────

run "empty_description_is_rejected" {
  command         = plan
  expect_failures = [var.description]

  variables {
    name        = "test-sg"
    vpc_id      = "vpc-00000000"
    description = ""
  }
}

run "null_description_falls_back_to_default" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
  }

  assert {
    condition     = aws_security_group.this[0].description == "Managed by Terraform - test-sg"
    error_message = "null description should fall back to 'Managed by Terraform - <name>'."
  }
}

# ── ingress one-of validation ────────────────────────────────────────────────

run "ingress_with_no_source_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
      }
    }
  }
}

run "ingress_with_two_sources_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "10.0.0.0/8"
        cidr_ipv6   = "::/0"
      }
    }
  }
}

# ── egress one-of validation ─────────────────────────────────────────────────

run "egress_with_no_destination_is_rejected" {
  command         = plan
  expect_failures = [var.egress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    egress_rules = {
      bad = {
        ip_protocol = "-1"
      }
    }
  }
}

# ── port semantics validation ────────────────────────────────────────────────

run "tcp_rule_without_ports_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }
}

run "all_protocols_rule_without_ports_is_accepted" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      all_from_vpc = {
        ip_protocol = "-1"
        cidr_ipv4   = "10.0.0.0/16"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["all_from_vpc"].ip_protocol == "-1"
    error_message = "Rule with ip_protocol = -1 should be accepted without from_port/to_port."
  }
}

run "ingress_port_out_of_range_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = 99999
        to_port     = 99999
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }
}

run "egress_port_out_of_range_is_rejected" {
  command         = plan
  expect_failures = [var.egress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    egress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = 70000
        to_port     = 70000
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  }
}

run "ingress_all_protocols_with_ports_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "-1"
        from_port   = 0
        to_port     = 65535
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }
}

run "egress_all_protocols_with_ports_is_rejected" {
  command         = plan
  expect_failures = [var.egress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    egress_rules = {
      bad = {
        ip_protocol = "-1"
        from_port   = 0
        to_port     = 65535
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  }
}

run "ingress_from_port_greater_than_to_port_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 80
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }
}

run "egress_from_port_greater_than_to_port_is_rejected" {
  command         = plan
  expect_failures = [var.egress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    egress_rules = {
      bad = {
        ip_protocol = "udp"
        from_port   = 600
        to_port     = 500
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  }
}

run "ingress_tcp_with_negative_one_ports_is_rejected" {
  command         = plan
  expect_failures = [var.ingress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      bad = {
        ip_protocol = "tcp"
        from_port   = -1
        to_port     = -1
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }
}

run "egress_udp_with_negative_one_ports_is_rejected" {
  command         = plan
  expect_failures = [var.egress_rules]

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    egress_rules = {
      bad = {
        ip_protocol = "udp"
        from_port   = -1
        to_port     = -1
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  }
}

run "icmp_echo_request_type_and_code_is_accepted" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      echo = {
        ip_protocol = "icmp"
        from_port   = 8
        to_port     = 0
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["echo"].from_port == 8
    error_message = "ICMP echo-request (type 8, code 0) should be accepted even though from_port > to_port, because for ICMP those are type and code, not a port range."
  }
}

run "icmp_all_types_and_codes_is_accepted" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      all_icmp = {
        ip_protocol = "icmp"
        from_port   = -1
        to_port     = -1
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["all_icmp"].ip_protocol == "icmp"
    error_message = "ICMP with from_port = to_port = -1 (any type / any code) should be accepted."
  }
}

# ── SG uses name_prefix ──────────────────────────────────────────────────────

run "sg_uses_name_prefix" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-00000000"
  }

  assert {
    condition     = aws_security_group.this[0].name_prefix == "test-sg-"
    error_message = "Security group should use name_prefix (not a fixed name) to support create_before_destroy."
  }
}

# ── create = false produces no resources ─────────────────────────────────────

run "create_false_produces_no_resources" {
  command = plan

  variables {
    create = false
    name   = "test-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      https = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "10.0.0.0/8"
      }
    }
  }

  assert {
    condition     = length(aws_security_group.this) == 0
    error_message = "No SG should be created when create = false."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "No ingress rules should be created when create = false."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "No egress rules should be created when create = false."
  }
}
