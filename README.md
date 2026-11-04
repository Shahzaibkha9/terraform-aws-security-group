# terraform-aws-security-group

[![CI](https://github.com/sudo-terraform-aws-modules/terraform-aws-security-group/actions/workflows/main.yml/badge.svg)](https://github.com/sudo-terraform-aws-modules/terraform-aws-security-group/actions/workflows/main.yml)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D%201.3.0-blue)](https://developer.hashicorp.com/terraform/downloads)
[![AWS Provider](https://img.shields.io/badge/aws-%3E%3D%206.0.0-orange)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](./LICENSE)

<img width="600" alt="SUDO x AWS" src="https://github.com/user-attachments/assets/f7044ff9-afce-4811-91c6-2f3c95635abb" />

A Terraform module for AWS security groups. Creates one `aws_security_group` and manages its ingress and egress rules via the modern `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources - never the legacy inline `ingress` / `egress` blocks.

## Default behaviour

Out of the box the module ships with secure defaults so a minimal configuration lands on the right side of security:

- `name_prefix` (not `name`) so `create_before_destroy` replacements do not collide with the existing SG via `InvalidGroup.Duplicate`.
- No ingress rules by default (deny-all). Pass `ingress_rules` to allow traffic.
- No egress rules by default (deny-all). AWS strips its "allow all" egress on SG creation and Terraform keeps it stripped. Pass `egress_rules` to open outbound.
- Separate rule resources (not inline `ingress` / `egress` blocks) so each rule has its own `security_group_rule_id`, tags, and description that persist across edits.
- `revoke_rules_on_delete` defaults to `false`; set to `true` only for SGs attached to AWS services (e.g. EMR) that add rules outside Terraform and create a cyclic dependency on destroy.
- Rules support four source / destination types - `cidr_ipv4`, `cidr_ipv6`, `prefix_list_id`, `referenced_security_group_id` - with a one-of validation enforced at plan time.

## Prerequisites

Before applying this module, make sure the following are in place:

- **Caller IAM permissions**: `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`, `ec2:DescribeSecurityGroups`, `ec2:DescribeSecurityGroupRules`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`, `ec2:RevokeSecurityGroupIngress`, `ec2:RevokeSecurityGroupEgress`, `ec2:CreateTags`, `ec2:DeleteTags`.
- **VPC** already exists. The module does not accept the default VPC - `vpc_id` is required.
- **Referenced SG IDs** on any rule using `referenced_security_group_id` must exist before apply.
- **Prefix list IDs** on any rule using `prefix_list_id` must exist before apply. For AWS-managed prefix lists, look them up with the `aws_prefix_list` data source.

### Immutable settings

Changing any of these after the first apply forces the security group to be replaced. The module's `create_before_destroy = true` means the new SG is created first and the old one is deleted after - but downstream resources that reference the old SG ID must be able to tolerate the brief overlap.

- `name` (any change forces replacement because it is the input to `name_prefix`)
- `vpc_id`
- `description`

Plan before applying any change to the inputs above.

### Costs

Security groups themselves are free. The only cost is the AWS API rate limit against the module's `ec2:AuthorizeSecurityGroup*` calls, which matters only at high rule counts (hundreds per SG).

### State and secrets

The module does not store secrets in state. Rule descriptions and tags are visible to anyone with read access to the Terraform state.

## Usage

### Minimal

```hcl
module "sg" {
  source = "sudo-terraform-aws-modules/security-group/aws"

  name   = "web"
  vpc_id = module.vpc.vpc_id

  ingress_rules = {
    https_from_vpc = {
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "10.0.0.0/16"
    }
  }
}
```

See `examples/minimal` for a runnable version.

### Complete (all four source types + per-rule tags)

```hcl
module "sg" {
  source = "sudo-terraform-aws-modules/security-group/aws"

  name        = "app"
  description = "Application tier security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https_corp = {
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = module.vpc.cidr_block
    }
    from_lb = {
      ip_protocol                  = "tcp"
      from_port                    = 8080
      to_port                      = 8080
      referenced_security_group_id = module.alb.security_group_id
    }
  }

  egress_rules = {
    to_s3 = {
      ip_protocol    = "tcp"
      from_port      = 443
      to_port        = 443
      prefix_list_id = data.aws_prefix_list.s3.id
    }
    to_vpc = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.cidr_block
    }
  }

  tags = { Environment = "production" }
}
```

See `examples/complete` for a runnable version.

## Security recommendations

### Deny-all defaults, not allow-all

The old security-group convention of "allow all egress by default" is a holdover from EC2-Classic. For a modern VPC-attached SG, deny-all egress and open only what the workload needs. The module ships that way. If you need "all outbound" explicitly, pass:

```hcl
egress_rules = {
  all = {
    ip_protocol = "-1"
    cidr_ipv4   = "0.0.0.0/0"
    description = "Allow all outbound"
  }
}
```

### Prefer `referenced_security_group_id` over CIDRs for in-VPC traffic

When one SG talks to another in the same VPC, use `referenced_security_group_id` rather than hard-coding the destination CIDR. The rule stays correct across subnet changes, secondary VPC CIDRs, and multi-AZ expansion.

### Scope egress to prefix lists for AWS services

Egress to AWS services (S3, DynamoDB, STS, etc.) belongs in a `prefix_list_id` rule, not `0.0.0.0/0`. AWS-managed prefix lists resolve to the actual service IP ranges in the current region.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create"></a> [create](#input\_create) | Controls whether the security group and its rules are created. Set to false to produce no resources. | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the security group. Shown in the AWS console. Defaults to 'Managed by Terraform - <name>' when null. Cannot be an empty string (AWS rejects it). | `string` | `null` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Map of egress rules. Key is a logical name referenced in outputs and tags.<br/>Exactly one destination must be set per rule: cidr\_ipv4, cidr\_ipv6, prefix\_list\_id, or referenced\_security\_group\_id.<br/>Defaults to an empty map (no egress allowed - deny-all by default). AWS removes the default allow-all egress on creation.<br/><br/>Example (allow all outbound):<br/>  egress\_rules = {<br/>    all = {<br/>      ip\_protocol = "-1"<br/>      cidr\_ipv4   = "0.0.0.0/0"<br/>      description = "Allow all outbound traffic"<br/>    }<br/>  }<br/><br/>Example (restricted to a VPC CIDR):<br/>  egress\_rules = {<br/>    vpc\_only = {<br/>      ip\_protocol = "-1"<br/>      cidr\_ipv4   = "10.0.0.0/16"<br/>    }<br/>  } | <pre>map(object({<br/>    ip_protocol                  = string<br/>    from_port                    = optional(number, null)<br/>    to_port                      = optional(number, null)<br/>    cidr_ipv4                    = optional(string, null)<br/>    cidr_ipv6                    = optional(string, null)<br/>    prefix_list_id               = optional(string, null)<br/>    referenced_security_group_id = optional(string, null)<br/>    description                  = optional(string, "")<br/>    tags                         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Map of ingress rules. Key is a logical name referenced in outputs and tags.<br/>Exactly one source must be set per rule: cidr\_ipv4, cidr\_ipv6, prefix\_list\_id, or referenced\_security\_group\_id.<br/>Defaults to an empty map (no ingress allowed - deny-all by default).<br/><br/>Example (HTTPS from a known CIDR):<br/>  ingress\_rules = {<br/>    https\_corp = {<br/>      ip\_protocol = "tcp"<br/>      from\_port   = 443<br/>      to\_port     = 443<br/>      cidr\_ipv4   = "10.0.0.0/8"<br/>      description = "HTTPS from corp network"<br/>    }<br/>  }<br/><br/>Example (all traffic from a referenced SG):<br/>  ingress\_rules = {<br/>    from\_app = {<br/>      ip\_protocol                  = "-1"<br/>      referenced\_security\_group\_id = aws\_security\_group.app.id<br/>    }<br/>  } | <pre>map(object({<br/>    ip_protocol                  = string<br/>    from_port                    = optional(number, null)<br/>    to_port                      = optional(number, null)<br/>    cidr_ipv4                    = optional(string, null)<br/>    cidr_ipv6                    = optional(string, null)<br/>    prefix_list_id               = optional(string, null)<br/>    referenced_security_group_id = optional(string, null)<br/>    description                  = optional(string, "")<br/>    tags                         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the security group. Used as the prefix for the AWS name\_prefix so replacements do not collide with the existing SG. | `string` | n/a | yes |
| <a name="input_revoke_rules_on_delete"></a> [revoke\_rules\_on\_delete](#input\_revoke\_rules\_on\_delete) | If true, revoke all ingress and egress rules on the security group before destroying it. Only needed when another AWS service (e.g. EMR) adds rules outside Terraform that create a cyclic dependency. Defaults to false. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the security group and merged into every ingress/egress rule. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the security group lives. Required - defaulting to the region's default VPC is a well-known footgun. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the security group. Null when create = false. |
| <a name="output_egress_rule_arns"></a> [egress\_rule\_arns](#output\_egress\_rule\_arns) | Map of logical egress rule key to ARN. |
| <a name="output_egress_rule_ids"></a> [egress\_rule\_ids](#output\_egress\_rule\_ids) | Map of logical egress rule key to AWS security\_group\_rule\_id. |
| <a name="output_id"></a> [id](#output\_id) | ID of the security group. Null when create = false. |
| <a name="output_ingress_rule_arns"></a> [ingress\_rule\_arns](#output\_ingress\_rule\_arns) | Map of logical ingress rule key to ARN. |
| <a name="output_ingress_rule_ids"></a> [ingress\_rule\_ids](#output\_ingress\_rule\_ids) | Map of logical ingress rule key to AWS security\_group\_rule\_id. |
| <a name="output_name"></a> [name](#output\_name) | Final AWS name of the security group (name\_prefix plus the random suffix). Null when create = false. |
| <a name="output_owner_id"></a> [owner\_id](#output\_owner\_id) | AWS account ID that owns the security group. Null when create = false. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID the security group lives in. Null when create = false. |
<!-- END_TF_DOCS -->
