output "id" {
  description = "ID of the security group. Null when create = false."
  value       = try(aws_security_group.this[0].id, null)
}

output "arn" {
  description = "ARN of the security group. Null when create = false."
  value       = try(aws_security_group.this[0].arn, null)
}

output "name" {
  description = "Final AWS name of the security group (name_prefix plus the random suffix). Null when create = false."
  value       = try(aws_security_group.this[0].name, null)
}

output "vpc_id" {
  description = "VPC ID the security group lives in. Null when create = false."
  value       = try(aws_security_group.this[0].vpc_id, null)
}

output "owner_id" {
  description = "AWS account ID that owns the security group. Null when create = false."
  value       = try(aws_security_group.this[0].owner_id, null)
}

output "ingress_rule_ids" {
  description = "Map of logical ingress rule key to AWS security_group_rule_id."
  value       = { for k, v in aws_vpc_security_group_ingress_rule.this : k => v.security_group_rule_id }
}

output "ingress_rule_arns" {
  description = "Map of logical ingress rule key to ARN."
  value       = { for k, v in aws_vpc_security_group_ingress_rule.this : k => v.arn }
}

output "egress_rule_ids" {
  description = "Map of logical egress rule key to AWS security_group_rule_id."
  value       = { for k, v in aws_vpc_security_group_egress_rule.this : k => v.security_group_rule_id }
}

output "egress_rule_arns" {
  description = "Map of logical egress rule key to ARN."
  value       = { for k, v in aws_vpc_security_group_egress_rule.this : k => v.arn }
}
