resource "aws_security_group" "this" {
  count = var.create ? 1 : 0

  # name_prefix (not name) so create_before_destroy replacements do not
  # collide with the existing SG via InvalidGroup.Duplicate.
  name_prefix = "${var.name}-"
  description = coalesce(var.description, "Managed by Terraform - ${var.name}")
  vpc_id      = var.vpc_id

  revoke_rules_on_delete = var.revoke_rules_on_delete

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Rules ─────────────────────────────────────────────────────────────────────

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.create ? var.ingress_rules : {}

  security_group_id            = aws_security_group.this[0].id
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  description                  = each.value.description

  tags = merge(var.tags, each.value.tags, { Name = "${var.name}-ingress-${each.key}" })
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.create ? var.egress_rules : {}

  security_group_id            = aws_security_group.this[0].id
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  description                  = each.value.description

  tags = merge(var.tags, each.value.tags, { Name = "${var.name}-egress-${each.key}" })
}
