#!/usr/bin/env bash
# Stop hook: if this session touched any .tf files, terraform validate must pass
# before the session is allowed to end.
# Fires on the Stop event — Claude cannot close the session until this exits 0.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Only run if any .tf files were modified in this session.
# Check for modified tf files relative to HEAD (staged or unstaged).
if ! git -C "${REPO_ROOT}" diff --name-only HEAD 2>/dev/null | grep -q '\.tf$'; then
  if ! git -C "${REPO_ROOT}" diff --name-only 2>/dev/null | grep -q '\.tf$'; then
    exit 0
  fi
fi

# Find changed environment directories and validate each one.
CHANGED_ENVS=$(git -C "${REPO_ROOT}" diff --name-only HEAD 2>/dev/null \
  | grep '\.tf$' \
  | sed 's|/[^/]*$||' \
  | sort -u)

FAILED=0
for dir in $CHANGED_ENVS; do
  FULL_PATH="${REPO_ROOT}/${dir}"
  if [[ -d "${FULL_PATH}" ]]; then
    if ! terraform -chdir="${FULL_PATH}" validate -no-color 2>&1; then
      echo "ERROR: terraform validate failed in ${dir} — session cannot close until fixed." >&2
      FAILED=1
    fi
  fi
done

if [[ "${FAILED}" -eq 1 ]]; then
  exit 2
fi
