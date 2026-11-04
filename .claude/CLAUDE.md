# CLAUDE.md

Project-scoped context for Claude Code and AGENTS.md-aware runtimes (Codex, Kiro, GitLab Duo, etc.). Claude Code reads this file from `.claude/` directly; the root `AGENTS.md` symlink points here for the other runtimes.

## What this repository is

A Terraform module for AWS, generated from [sudo-terraform-module-template](https://github.com/sudo-terraform-aws-modules/sudo-terraform-module-template) and maintained by SUDO Consultants. One module, one focused AWS capability.

## Git workflow (non-negotiable)

- Never commit to `main` or `master`. Create a feature branch for every task. Local guards: `no-commit-to-branch` (commit time) and the pre-push hook in `scripts/hooks/` (push time).
- Commit messages follow Conventional Commits. Allowed types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`, `build`, `revert`. The commit-msg hook rejects anything else.
- Do not amend or force-push shared branches; add new commits instead.
- Never edit files under `.terraform/` or commit `*.tfstate` or `.terraform.lock.hcl`.

## How to validate (run before declaring work done)

```text
make fmt        # terraform fmt -recursive
make lint       # tflint --config=.tflint.hcl
make checkov    # checkov security scan
make validate   # terraform init -backend=false && terraform validate
make docs       # regenerate README terraform-docs section (do not hand-edit it)
make pre-commit # all pre-commit hooks against all files
```

The README's Requirements/Providers/Inputs/Outputs tables between the `BEGIN_TF_DOCS`/`END_TF_DOCS` markers are generated. Change `variables.tf` / `outputs.tf` and run `make docs` instead of editing them.

## Contributing checklist

1. Branch from `main`.
2. Make the change; update or add `examples/` when the module API changes.
3. `make fmt lint checkov` clean, `make docs` regenerated, `CHANGELOG.md` updated under `[Unreleased]`.
4. Conventional commit message.
5. Open a PR; CI runs pre-commit and checkov and must pass.

## Terraform conventions

All module conventions, version-floor guards, HCL patterns, security rules, testing strategy, and semver discipline live in `.claude/skills/terraform/SKILL.md`.

Load it (or let Claude Code auto-discover it) before writing or reviewing any Terraform in this repository.
