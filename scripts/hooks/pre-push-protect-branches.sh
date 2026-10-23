#!/usr/bin/env bash
# Reject direct pushes to protected branches (main, master).
#
# Wired into the pre-commit framework as a pre-push stage hook - see
# .pre-commit-config.yaml. Installed automatically by `pre-commit install`
# (default_install_hook_types includes pre-push) or `make setup`.
#
# pre-commit exposes the remote branch being pushed to via
# PRE_COMMIT_REMOTE_BRANCH (e.g. refs/heads/main). When run outside
# pre-commit (as a plain .git/hooks/pre-push), it falls back to reading
# the standard pre-push stdin ref lines.

set -euo pipefail

protected='^refs/heads/(main|master)$'

fail() {
    cat >&2 << 'MSG'
ERROR: Direct pushes to 'main' and 'master' are not allowed.

This repository uses a branch-based workflow:

  1. Create a feature branch:   git switch -c feat/my-change
  2. Commit using Conventional Commits (feat:, fix:, docs:, ...)
  3. Push the branch and open a pull request

Remote branch protection enforces the same rule; this hook catches the
mistake before the push leaves your machine.
MSG
    exit 1
}

if [[ -n "${PRE_COMMIT_REMOTE_BRANCH:-}" ]]; then
    # Running under the pre-commit framework.
    if [[ "${PRE_COMMIT_REMOTE_BRANCH}" =~ ${protected} ]]; then
        fail
    fi
else
    # Running as a plain git pre-push hook: stdin lines are
    # "<local ref> <local sha> <remote ref> <remote sha>".
    while read -r _local_ref _local_sha remote_ref _remote_sha; do
        if [[ "${remote_ref}" =~ ${protected} ]]; then
            fail
        fi
    done
fi

exit 0
