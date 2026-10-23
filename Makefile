.PHONY: help setup fmt validate lint checkov docs pre-commit

help:
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

setup: ## Install terraform-docs and pre-commit (requires mise + uv)
	# mise:  https://mise.jdx.dev/installing-mise.html
	# uv:    https://docs.astral.sh/uv/getting-started/installation/
	mise use -g terraform-docs@latest
	uv tool install pre-commit
	# Installs pre-commit, commit-msg, and pre-push hooks
	# (default_install_hook_types in .pre-commit-config.yaml).
	pre-commit install

fmt: ## Run terraform fmt
	terraform fmt -recursive

validate: ## Run terraform validate (requires terraform init first)
	terraform init -backend=false -input=false
	terraform validate

lint: ## Run tflint
	tflint --config=.tflint.hcl

checkov: ## Run checkov security scan
	checkov --config-file checkov.yaml -d .

docs: ## Generate terraform-docs README
	terraform-docs markdown table --output-file README.md --output-mode inject .

pre-commit: ## Run all pre-commit hooks against all files
	SKIP=no-commit-to-branch pre-commit run --all-files

all: fmt lint checkov ## Run fmt + lint + checkov
