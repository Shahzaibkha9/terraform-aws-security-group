---
name: terraform
description: Use when writing, reviewing, or generating Terraform modules from this template. Covers module conventions, version-floor guards, HCL patterns, testing, security scanning, and semver discipline.
---

# Terraform Module Skill

Activate when writing, reviewing, or generating Terraform modules from this template. Covers module conventions, version-floor guards, HCL patterns, testing, security scanning, and semver discipline.

---

## Runtime & Version Floor

- Terraform: `>= 1.3.0` (set in `versions.tf`)
- AWS provider: `>= 6.0.0`
- Runtime: Terraform (not OpenTofu)

### Feature Guard - Do NOT Emit

Features below are above the 1.3.0 floor. Never emit them unless `required_version` is raised first.

| Feature | Minimum version | Consequence if emitted at 1.3 |
|---------|----------------|-------------------------------|
| `check` blocks | 1.5 | Parse error |
| `import` blocks (declarative) | 1.5 | Parse error |
| native `terraform test` | 1.6 | Command not found |
| `removed` blocks | 1.7 | Parse error |
| mock providers | 1.7 | Test parse error |
| provider-defined functions | 1.8 | Parse error |
| cross-variable `validation` (referencing other `var.*`) | 1.9 | Parse error |
| `templatestring()` function | 1.9 | Unknown function error |
| S3 native lock-file (`use_lockfile`) | 1.10 | Unsupported argument |
| ephemeral values | 1.10 | Parse error |
| `write_only` / `*_wo` arguments | 1.11 | Unsupported argument |

If a feature is needed, raise `required_version` in the same commit and document the bump in the changelog / PR description.

---

## Reusable Module Rules

### Provider & Backend

- [NO] A reusable module MUST NOT contain a `provider` block (no default provider config).
- [NO] A reusable module MUST NOT contain a `backend` block.
- [OK] Aliased providers are passed via `configuration_aliases` in `required_providers`:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0.0"
      configuration_aliases = [aws.replica]  # only when multi-region
    }
  }
}
```

The caller passes `providers = { aws.replica = aws.eu_west_1 }` on the module block.

### No Hardcoded ARN Partition

- [NO] Never hardcode `arn:aws:` literals: breaks GovCloud (`aws-us-gov`) and China (`aws-cn`).
- [OK] Use `data.aws_partition.current.partition` or `data.aws_caller_identity` / `data.aws_region`:

```hcl
data "aws_partition" "current" {}

locals {
  arn_prefix = "arn:${data.aws_partition.current.partition}"
}
```

### moved Blocks - Preserve Consumer State

When renaming a resource or module address in a published module, ALWAYS add a `moved` block in the same commit. Without it, every consumer's next plan shows a destroy+create, which replaces live infrastructure.

```hcl
moved {
  from = aws_iam_role.lambda
  to   = aws_iam_role.execution
}
```

- `moved` cannot cross provider boundaries or state files.
- Place `moved` blocks inside the module that owns the renamed address. Consumers pick them up on the next `init`/`plan` automatically.
- Do NOT place a `moved` block inside a module that is itself being removed. The block is unreachable once the module call is deleted from the consumer's configuration.

---

## Variables

### Defaults

- Optional variables default to `null`, not `""` (empty string).
- Boolean variables default to the safe/conservative setting (e.g. `create_x = false`, `enable_encryption = true`).
- Use `nullable = false` (1.1+) when a variable must never be `null`.

### Type Contracts

- Always specify an explicit `type`.
- Prefer typed `object()` with `optional()` (1.3+) over `map(any)` or `any`.
- Always include `description`.

### Validation

- Use `validation` blocks referencing only the variable's own value (cross-variable validation requires 1.9, above our floor).
- `validation` blocks belong in the same variable block, after `default`.

### Variable Block Ordering

```
description -> type -> default -> sensitive -> nullable -> validation
```

---

## Outputs

### sensitive = true

- Mark any output that exposes credentials, tokens, private keys, or connection strings as `sensitive = true`.

### count-Gated Resources

When a resource uses `count = var.create_x ? 1 : 0`, the output must handle the empty-list case. Use one() or try(..., null):

```hcl
output "role_arn" {
  description = "ARN of the IAM role, or null when not created"
  value       = try(aws_iam_role.this[0].arn, null)
}
```

Alternatively:

```hcl
output "role_arn" {
  description = "ARN of the IAM role, or null when not created"
  value       = one(aws_iam_role.this[*].arn)
}
```

Both return `null` when the resource is not created. Document that the output is nullable so consumers know to handle it.

### Output Block Ordering

```
description -> value -> sensitive
```

---

## Resource Patterns

### count vs for_each

| Scenario | Use | Why |
|----------|-----|-----|
| Boolean toggle (0 or 1 instance) | count = condition ? 1 : 0 | Simple optional singleton |
| Collection with stable identity | for_each = tomap(...) or toset(...) | Removing/reordering does not churn other addresses |
| Keys derived from computed attrs (IDs, ARNs) | Do not - use the input variable keys instead | for_each keys must be known at plan time |

- [NO] Never use `for_each` with keys derived from another resource's computed attributes: plan fails with "Invalid for_each argument".
- [OK] Drive `for_each` from user-supplied variables or static locals.
- [NO] `depends_on` does NOT fix unknown-key errors. It orders apply, not plan-time resolution.

### Resource Block Ordering

```
count / for_each  (first, blank line after)
-> arguments (logical grouping)
-> tags (last argument)
-> depends_on
-> lifecycle
```

### Naming

- The primary (or sole) resource of a given type in the module is named `this`.
- When a module contains multiple resources of the same type, give each a descriptive `snake_case` name that conveys its role.

---

## Locals

- Use locals for computed values, tag merging, and dependency ordering.
- Use `try()` (0.12.20+) instead of `element(concat(...), 0)`.

---

## Security & Scanning

- `checkov` runs via `make checkov` and CI (see `checkov.yaml`).
- `tflint` via `make lint` with `.tflint.hcl` config.
- Do NOT store secrets in variable defaults or `.tfvars`.
- `sensitive = true` only masks display, the value still lives in state. On pre-1.11, source secrets from a secrets manager at runtime.
- Encryption at rest: default to enabled (`enable_encryption = true`).
- Security groups: never open to `0.0.0.0/0` by default; use separate `aws_vpc_security_group_ingress_rule` / `egress_rule` resources instead of inline `ingress`/`egress` blocks.

---

## Testing Strategy

### At the 1.3 Floor

Native `terraform test` requires 1.6+. For modules at `>= 1.3.0`:

| Layer | Tool | What it validates |
|-------|------|-------------------|
| Static | `terraform validate`, `tflint`, `checkov` | Syntax, types, security policy |
| Plan-time | `terraform plan` on `examples/` | Resource graph, input wiring |
| Integration | Terratest (Go) or manual apply | Computed values, real provider behavior |

### When the Floor is Raised to 1.6+

- Use native `terraform test` with `command = plan` for input-derived assertions.
- Use `command = apply` for computed values (ARNs, generated names) and set-type nested blocks.
- Mock providers (1.7+) for unit tests; real cloud runs for integration.

---

## Semver & Breaking Changes

This is a published reusable module. Consumers pin with exact versions (e.g. `version = "2.1.0"`) in their lock files; source-constrained modules use `version = "X.Y.Z"` directly.

### What Constitutes a Breaking Change (major bump)

- Removing or renaming a variable, output, or resource address without a `moved` block.
- Changing a variable's type in a way that rejects previously valid inputs.
- Raising `required_version` or provider version floors.
- Removing a provider from `required_providers`.
- Changing a default value that alters infrastructure behavior (e.g. `enable_encryption` from `true` to `false`).

### What Is a Minor (feature) Change

- Adding a new variable with a safe default.
- Adding a new output.
- Adding a new resource gated by `count = var.create_x ? 1 : 0` (default `false`).

### What Is a Patch

- Documentation updates.
- Bug fixes that do not change the module interface.
- Internal refactors with `moved` blocks preserving all addresses.

### Commit Conventions

Use conventional commits: `feat:`, `fix:`, `feat!:` (breaking), `docs:`, `chore:`, `refactor:`.

---

## File Layout

```text
main.tf          - Primary resources
variables.tf     - All input variables
outputs.tf       - All output values
versions.tf      - required_version + required_providers (NO backend, NO provider block)
README.md        - Generated by terraform-docs
examples/
  minimal/       - Minimum viable usage (own versions.tf + provider block)
  complete/      - All features exercised (own versions.tf + provider block)
```

- Do NOT add `backend.tf`, `provider.tf`, or `terraform.tfvars` to the module root.
- `examples/` directories MAY contain `provider` blocks and `backend` configs (they are root modules).

---

## CI & Pre-commit

- Pre-commit hooks: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_docs`, conventional commits.
- CI: pre-commit + checkov (see `.github/workflows/main.yml`).
- `make all` runs fmt + lint + checkov.
- `make docs` regenerates README via `terraform-docs`.

---

## LLM Mistake Checklist

Before returning generated HCL, verify:

- [ ] No `provider` or `backend` block in the module root.
- [ ] No features above the 1.3 floor emitted without raising `required_version`.
- [ ] No hardcoded `arn:aws:`, use `data.aws_partition`.
- [ ] `for_each` keys are plan-time known (not computed IDs).
- [ ] `moved` blocks accompany any resource/module rename.
- [ ] Outputs from count-gated resources use `try(..., null)` or `one()`.
- [ ] Sensitive outputs marked `sensitive = true`.
- [ ] Optional variables default to `null`, booleans to the safe value.
- [ ] No `map(any)`, use typed objects with `optional()`.
- [ ] No `.terraform.lock.hcl` committed (it is gitignored).
- [ ] No `element(concat(...))`, use `try()`.
- [ ] No `ignore_changes = all` without explicit justification.
- [ ] Conventional commit message on the PR.
