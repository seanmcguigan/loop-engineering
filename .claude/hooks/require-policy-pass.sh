#!/usr/bin/env bash
# Hook: require-policy-pass
# Runs as a PreToolUse hook on Bash commands.
# Blocks writes to clusters/prod/ unless checkov has passed in the current turn.
# Checkov pass is signalled by either:
#   - The file .checkov-passed existing in the repo root (< 30 min old), OR
#   - CHECKOV_PASSED=true AND CHECKOV_PASSED_AT=<epoch seconds> set within the last 30 min.
#     Both variables are required together; CHECKOV_PASSED alone is not sufficient.
set -euo pipefail

INPUT="$(cat)"

# Extract the bash command being run.
# Fail closed if python3 is absent or JSON is malformed.
if ! COMMAND="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"; then
  cat >&2 <<'EOF'
ERROR: require-policy-pass hook could not parse the tool event JSON.
Blocking as a safe default — check your Python installation.
EOF
  exit 2
fi

# Only gate on commands that write to clusters/prod
if ! echo "$COMMAND" | grep -qE '(kubectl apply|terraform apply|flux reconcile|helm upgrade|helm install|kustomize build)'; then
  exit 0
fi

if ! echo "$COMMAND" | grep -qE 'clusters/prod'; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SENTINEL_FILE="${REPO_ROOT}/.checkov-passed"
MAX_AGE_SECONDS=1800

# Env var path: requires both CHECKOV_PASSED=true AND a fresh CHECKOV_PASSED_AT timestamp.
# CHECKOV_PASSED alone is not accepted — it has no freshness guarantee.
if [ "${CHECKOV_PASSED:-}" = "true" ]; then
  PASSED_AT="${CHECKOV_PASSED_AT:-0}"
  NOW="$(date +%s)"
  AGE=$(( NOW - PASSED_AT ))
  if [ "$AGE" -le "$MAX_AGE_SECONDS" ]; then
    exit 0
  fi
  # Fall through to sentinel file check; do not block yet in case sentinel is valid.
fi

# Sentinel file path: must exist and be < 30 minutes old
if [ -f "$SENTINEL_FILE" ]; then
  if [ "$(find "$SENTINEL_FILE" -mmin -30 2>/dev/null | wc -l)" -gt 0 ]; then
    exit 0
  else
    cat >&2 <<'EOF'
ERROR: The checkov sentinel file (.checkov-passed) is stale (older than 30 minutes).
Re-run checkov and OPA before applying to clusters/prod/:

  checkov -d clusters/prod/ --compact --quiet && \
  opa eval -d policies/ -i plan.json "data.platform.deny" && \
  touch .checkov-passed

EOF
    exit 2
  fi
fi

cat >&2 <<'EOF'
ERROR: Write to clusters/prod/ blocked — policy checks have not passed.

Before applying changes to the prod cluster, run:

  checkov -d clusters/prod/ --compact --quiet && \
  opa eval -d policies/ -i plan.json "data.platform.deny" && \
  touch .checkov-passed

Both checkov and OPA must exit cleanly. The sentinel file (.checkov-passed) must
exist and be less than 30 minutes old. Do not create the sentinel manually without
running the checks.

For CI, set both CHECKOV_PASSED=true and CHECKOV_PASSED_AT=$(date +%s) immediately
after the checks pass in the same job step.
EOF
exit 2
