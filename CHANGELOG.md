# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the module uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial implementation of the security group module.
- `aws_security_group` with `name_prefix` and `create_before_destroy` so replacements never collide with `InvalidGroup.Duplicate`.
- `ingress_rules` and `egress_rules` object types with four source / destination fields (`cidr_ipv4`, `cidr_ipv6`, `prefix_list_id`, `referenced_security_group_id`) and a one-of validation.
- Separate rule resources (`aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule`) instead of legacy inline blocks so each rule has its own `security_group_rule_id`, description, and tags.
- `revoke_rules_on_delete` variable for SGs attached to AWS services that add rules outside Terraform (e.g. EMR).
- Variable validations for `name` format and length, non-empty `description`, port range (`-1` to `65535`), and `ip_protocol` + port semantics (`-1` / `icmpv6` can omit ports).
- `create` guard that produces no resources when `create = false`.
- `tags` merged into the SG and into every rule, with per-rule `tags` overlay support.
- `examples/minimal` (single ingress rule) and `examples/complete` (all four source types + per-rule tags) usage examples.
- `tests/validations.tftest.hcl` and `tests/scenarios.tftest.hcl` using the built-in test framework and `mock_provider`.

### Security

- Deny-all ingress and egress by default. Callers opt in to every rule explicitly.
- Separate rule resources prevent the legacy inline-blocks footgun where editing one rule silently rewrites others.
