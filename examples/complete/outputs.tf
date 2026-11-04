output "security_group_id" {
  description = "ID of the created security group."
  value       = module.sg.id
}

output "ingress_rule_ids" {
  description = "Map of logical ingress rule key to AWS security_group_rule_id."
  value       = module.sg.ingress_rule_ids
}

output "egress_rule_ids" {
  description = "Map of logical egress rule key to AWS security_group_rule_id."
  value       = module.sg.egress_rule_ids
}
