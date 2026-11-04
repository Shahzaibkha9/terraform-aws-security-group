variable "create" {
  description = "Controls whether the security group and its rules are created. Set to false to produce no resources."
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the security group. Used as the prefix for the AWS name_prefix so replacements do not collide with the existing SG."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 240
    error_message = "name must be between 1 and 240 characters so the final AWS security group name (with suffix) stays within the 255 character limit."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.name))
    error_message = "name must only contain alphanumeric characters, hyphens, underscores, or dots - AWS security group names reject spaces and most punctuation."
  }
}

variable "description" {
  description = "Description of the security group. Shown in the AWS console. Defaults to 'Managed by Terraform - <name>' when null. Cannot be an empty string (AWS rejects it)."
  type        = string
  default     = null

  validation {
    condition     = var.description == null ? true : length(var.description) > 0
    error_message = "description cannot be an empty string. Pass null to use the module default, or provide a non-empty description."
  }
}

variable "vpc_id" {
  description = "VPC ID where the security group lives. Required - defaulting to the region's default VPC is a well-known footgun."
  type        = string
  nullable    = false
}

variable "revoke_rules_on_delete" {
  description = "If true, revoke all ingress and egress rules on the security group before destroying it. Only needed when another AWS service (e.g. EMR) adds rules outside Terraform that create a cyclic dependency. Defaults to false."
  type        = bool
  default     = false
}

# ── Rules ─────────────────────────────────────────────────────────────────────

variable "ingress_rules" {
  description = <<-EOT
    Map of ingress rules. Key is a logical name referenced in outputs and tags.
    Exactly one source must be set per rule: cidr_ipv4, cidr_ipv6, prefix_list_id, or referenced_security_group_id.
    Defaults to an empty map (no ingress allowed - deny-all by default).

    Example (HTTPS from a known CIDR):
      ingress_rules = {
        https_corp = {
          ip_protocol = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_ipv4   = "10.0.0.0/8"
          description = "HTTPS from corp network"
        }
      }

    Example (all traffic from a referenced SG):
      ingress_rules = {
        from_app = {
          ip_protocol                  = "-1"
          referenced_security_group_id = aws_security_group.app.id
        }
      }
  EOT
  type = map(object({
    ip_protocol                  = string
    from_port                    = optional(number, null)
    to_port                      = optional(number, null)
    cidr_ipv4                    = optional(string, null)
    cidr_ipv6                    = optional(string, null)
    prefix_list_id               = optional(string, null)
    referenced_security_group_id = optional(string, null)
    description                  = optional(string, "")
    tags                         = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ingress_rules :
      length(compact([v.cidr_ipv4, v.cidr_ipv6, v.prefix_list_id, v.referenced_security_group_id])) == 1
    ])
    error_message = "Each ingress_rules entry must set exactly one of: cidr_ipv4, cidr_ipv6, prefix_list_id, referenced_security_group_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.ingress_rules :
      contains(["-1", "icmpv6"], v.ip_protocol) ? true : (v.from_port != null && v.to_port != null)
    ])
    error_message = "Each ingress_rules entry must set from_port and to_port unless ip_protocol is '-1' (all protocols) or 'icmpv6'."
  }

  validation {
    condition = alltrue([
      for k, v in var.ingress_rules :
      v.from_port == null ? true : (v.from_port >= -1 && v.from_port <= 65535)
    ])
    error_message = "ingress_rules from_port must be between -1 and 65535. Use -1 only for ICMP types."
  }

  validation {
    condition = alltrue([
      for k, v in var.ingress_rules :
      v.to_port == null ? true : (v.to_port >= -1 && v.to_port <= 65535)
    ])
    error_message = "ingress_rules to_port must be between -1 and 65535. Use -1 only for ICMP codes."
  }
}

variable "egress_rules" {
  description = <<-EOT
    Map of egress rules. Key is a logical name referenced in outputs and tags.
    Exactly one destination must be set per rule: cidr_ipv4, cidr_ipv6, prefix_list_id, or referenced_security_group_id.
    Defaults to an empty map (no egress allowed - deny-all by default). AWS removes the default allow-all egress on creation.

    Example (allow all outbound):
      egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
          description = "Allow all outbound traffic"
        }
      }

    Example (restricted to a VPC CIDR):
      egress_rules = {
        vpc_only = {
          ip_protocol = "-1"
          cidr_ipv4   = "10.0.0.0/16"
        }
      }
  EOT
  type = map(object({
    ip_protocol                  = string
    from_port                    = optional(number, null)
    to_port                      = optional(number, null)
    cidr_ipv4                    = optional(string, null)
    cidr_ipv6                    = optional(string, null)
    prefix_list_id               = optional(string, null)
    referenced_security_group_id = optional(string, null)
    description                  = optional(string, "")
    tags                         = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.egress_rules :
      length(compact([v.cidr_ipv4, v.cidr_ipv6, v.prefix_list_id, v.referenced_security_group_id])) == 1
    ])
    error_message = "Each egress_rules entry must set exactly one of: cidr_ipv4, cidr_ipv6, prefix_list_id, referenced_security_group_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.egress_rules :
      contains(["-1", "icmpv6"], v.ip_protocol) ? true : (v.from_port != null && v.to_port != null)
    ])
    error_message = "Each egress_rules entry must set from_port and to_port unless ip_protocol is '-1' (all protocols) or 'icmpv6'."
  }

  validation {
    condition = alltrue([
      for k, v in var.egress_rules :
      v.from_port == null ? true : (v.from_port >= -1 && v.from_port <= 65535)
    ])
    error_message = "egress_rules from_port must be between -1 and 65535."
  }

  validation {
    condition = alltrue([
      for k, v in var.egress_rules :
      v.to_port == null ? true : (v.to_port >= -1 && v.to_port <= 65535)
    ])
    error_message = "egress_rules to_port must be between -1 and 65535."
  }
}

# ── Tagging ───────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags applied to the security group and merged into every ingress/egress rule."
  type        = map(string)
  nullable    = false
  default     = {}
}
