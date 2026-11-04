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
    name   = "has spaces & punctuation!"
    vpc_id = "vpc-00000000"
  }
}

run "name_too_long_is_rejected" {
  command         = plan
  expect_failures = [var.name]

  variables {
    name   = join("", [for _ in range(241) : "a"])
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
