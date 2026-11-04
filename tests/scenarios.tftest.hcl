# End-to-end plan scenarios. Each run exercises a realistic configuration
# shape (not just a single validation) and asserts the key resources plan.
# Uses the mock provider so no AWS credentials are required.

mock_provider "aws" {}

# ── Minimal shape: SG with one ingress, no egress ────────────────────────────

run "scenario_minimal_ingress_no_egress" {
  command = plan

  variables {
    name   = "web-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      https = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "10.0.0.0/16"
      }
    }
  }

  assert {
    condition     = length(aws_security_group.this) == 1
    error_message = "One SG should plan."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1
    error_message = "One ingress rule should plan."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "No egress rules should plan when egress_rules is left as default (empty)."
  }
}

# ── All four source types in one SG ──────────────────────────────────────────

run "scenario_all_four_source_types" {
  command = plan

  variables {
    name   = "mixed-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      from_cidr4 = {
        ip_protocol = "tcp"
        from_port   = 80
        to_port     = 80
        cidr_ipv4   = "10.0.0.0/16"
      }
      from_cidr6 = {
        ip_protocol = "tcp"
        from_port   = 80
        to_port     = 80
        cidr_ipv6   = "::/0"
      }
      from_prefix_list = {
        ip_protocol    = "tcp"
        from_port      = 443
        to_port        = 443
        prefix_list_id = "pl-00000001"
      }
      from_sg = {
        ip_protocol                  = "tcp"
        from_port                    = 8080
        to_port                      = 8080
        referenced_security_group_id = "sg-00000001"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 4
    error_message = "All four ingress rules should plan."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["from_sg"].referenced_security_group_id == "sg-00000001"
    error_message = "SG-to-SG reference should pass through verbatim."
  }
}

# ── All protocols rule (ip_protocol = -1) ────────────────────────────────────

run "scenario_all_protocols_rule" {
  command = plan

  variables {
    name   = "allprotos-sg"
    vpc_id = "vpc-00000000"
    ingress_rules = {
      everything = {
        ip_protocol = "-1"
        cidr_ipv4   = "10.0.0.0/16"
        description = "All protocols from VPC"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["everything"].ip_protocol == "-1"
    error_message = "ip_protocol = -1 should pass through unchanged."
  }
}

# ── Tags cascade: module tags + rule tags merge ──────────────────────────────

run "scenario_tags_merge" {
  command = plan

  variables {
    name   = "tagged-sg"
    vpc_id = "vpc-00000000"
    tags = {
      Environment = "production"
      Team        = "platform"
    }
    ingress_rules = {
      https = {
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "10.0.0.0/16"
        tags        = { Scope = "corp" }
      }
    }
  }

  assert {
    condition     = aws_security_group.this[0].tags["Environment"] == "production"
    error_message = "SG should carry module-level tags."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https"].tags["Environment"] == "production"
    error_message = "Rules should inherit module-level tags."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https"].tags["Scope"] == "corp"
    error_message = "Rules should carry their own per-rule tags."
  }
}

# ── revoke_rules_on_delete pass-through ──────────────────────────────────────

run "scenario_revoke_rules_on_delete" {
  command = plan

  variables {
    name                   = "emr-sg"
    vpc_id                 = "vpc-00000000"
    revoke_rules_on_delete = true
  }

  assert {
    condition     = aws_security_group.this[0].revoke_rules_on_delete == true
    error_message = "revoke_rules_on_delete should flow through to the SG resource."
  }
}

# ── examples/minimal plans cleanly ───────────────────────────────────────────

run "example_minimal_plans_cleanly" {
  command = plan

  module {
    source = "./examples/minimal"
  }

  variables {
    name   = "example-min"
    vpc_id = "vpc-00000000"
  }
}

# ── examples/complete plans cleanly ──────────────────────────────────────────

run "example_complete_plans_cleanly" {
  command = plan

  module {
    source = "./examples/complete"
  }

  variables {
    name                  = "example-full"
    vpc_id                = "vpc-00000000"
    vpc_cidr              = "10.0.0.0/16"
    app_security_group_id = "sg-00000001"
    s3_prefix_list_id     = "pl-00000001"
  }
}
