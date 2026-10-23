## Summary

<!-- Briefly describe what this PR does and why. -->

## Type of Change

<!-- Check all that apply -->

- [ ] `feat` - New feature or capability
- [ ] `fix` - Bug fix
- [ ] `refactor` - Code restructure without behavior change
- [ ] `docs` - Documentation only
- [ ] `ci` - CI/CD pipeline changes
- [ ] `chore` - Maintenance, dependency updates, tooling
- [ ] `perf` - Performance improvement
- [ ] `test` - Test additions or updates
- [ ] `revert` - Reverts a previous commit
- [ ] `breaking` - Breaking change (existing consumers must update)

## Related Issues

<!-- Link issues using keywords so GitHub auto-closes them on merge -->

- Closes #
- Implements #
- Updates #
- Related to #
- Blocked by #

## Changes Made

<!--
List the key changes. Be specific enough that a reviewer can follow along.
Example:
- Added `var.enable_encryption` with default `true`
- Removed deprecated `aws_s3_bucket_acl` resource
- Updated `versions.tf` to require AWS provider >= 6.0
-->

-
-
-

## Terraform Checklist

- [ ] `make fmt` - no formatting changes
- [ ] `make lint` - tflint passes
- [ ] `make validate` - terraform validate passes
- [ ] `make checkov` - no new security findings
- [ ] `make docs` - README updated if variables/outputs changed
- [ ] `.tflint.hcl` updated if new rules needed
- [ ] `checkov.yaml` updated if new skip rules needed

## Module Interface Changes

<!-- Fill in only if variables, outputs, or providers changed. Delete if not applicable. -->

| Type | Name | Change |
|------|------|--------|
| variable | | added / removed / modified |
| output | | added / removed / modified |
| provider | | added / removed / version bump |

## Breaking Changes

<!-- If this is a breaking change, describe what consumers need to update. Delete if not applicable. -->

**Impact:** <!-- Who is affected -->
**Migration:** <!-- What they need to change -->

## Testing

<!-- Describe how you tested this. Which example was used? Was it applied against real infrastructure? -->

- [ ] Tested with `examples/minimal`
- [ ] Tested with `examples/complete`
- [ ] Tested against real AWS account

## Additional Notes

<!-- Anything else reviewers should know: deployment order, known limitations, follow-up tasks. -->
