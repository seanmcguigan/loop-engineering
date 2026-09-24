#!/usr/bin/env bash
# Hook: block-prod-without-ticket
# Runs as a PreToolUse hook on Bash commands.
# Reads the JSON event from stdin; exits 1 if the command touches a prod-tagged
# resource but no ticket reference is present in the current commit message or
# the TICKET env var.
set -euo pipefail

INPUT="$(cat)"

# Extract the bash command being run.
# Fail closed (exit 1) if python3 is absent or the JSON is malformed — safer than
# silently allowing through an unvalidated command.
if ! COMMAND="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)"; then
  cat >&2 <<'EOF'
ERROR: block-prod-without-ticket hook could not parse the tool event JSON.
python3 may be unavailable or the event format unexpected.
Blocking as a safe default — check your Python installation.
EOF
  exit 2
fi

# Only inspect commands that could write prod resources
if ! echo "$COMMAND" | grep -qE '(terraform apply|kubectl apply|kubectl delete|flux reconcile|helm upgrade|helm install)'; then
  exit 0
fi

# Check if the command targets prod
TARGETS_PROD=false
if echo "$COMMAND" | grep -qE '(env=prod|clusters/prod|namespace.*prod|-n prod)'; then
  TARGETS_PROD=true
fi

if [ "$TARGETS_PROD" = "false" ]; then
  exit 0
fi

# Look for a ticket reference — accept TICKET env var, or scan the last commit message
TICKET_PATTERN='[A-Z]+-[0-9]+'

if [ -n "${TICKET:-}" ]; then
  if echo "$TICKET" | grep -qE "$TICKET_PATTERN"; then
    exit 0
  fi
fi

# Check the most recent git commit message
if git rev-parse --git-dir > /dev/null 2>&1; then
  COMMIT_MSG="$(git log -1 --format='%s %b' 2>/dev/null || true)"
  if echo "$COMMIT_MSG" | grep -qE "$TICKET_PATTERN"; then
    exit 0
  fi
fi

cat >&2 <<'EOF'
ERROR: Prod change blocked — no ticket reference found.

Any command that modifies prod resources (env=prod / clusters/prod) requires a
ticket reference in one of:
  - The current git commit message (e.g. "feat: update ingress [PLAT-1234]")
  - The TICKET environment variable (e.g. export TICKET=PLAT-1234)

Please add a ticket reference and retry.
EOF
exit 2
