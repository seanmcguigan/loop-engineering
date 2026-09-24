#!/usr/bin/env bash
set -euo pipefail

# Reads CI failures, open issues, and recent commits; writes findings to state/triage-$(date).md
# Designed to run on a schedule (e.g. nightly cron or GitHub Actions schedule trigger).
# Each run is a fresh claude -p invocation — no accumulated context degradation.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
TRIAGE_DIR="${REPO_ROOT}/triage"
DATE="$(date +%Y-%m-%d)"
FINDINGS_FILE="${STATE_DIR}/triage-${DATE}.md"

mkdir -p "${STATE_DIR}" "${TRIAGE_DIR}"

# Run claude -p and capture the API response; handle failures without aborting the whole script.
# Claude writes the findings markdown to FINDINGS_FILE via its Write tool.
API_RESPONSE="$(claude -p "
You are a triage automation running on the platform-loops repo.

1. Read CI failures from the last 24h: run \`gh run list --limit 20 --json conclusion,name,url\` and identify any failures.
2. Read open issues labelled 'platform' or 'sre': run \`gh issue list --label platform,sre --json number,title,url,createdAt\`.
3. Read recent commits to main: run \`git log --oneline --since='24 hours ago'\`.
4. Run \`flux get kustomizations --all-namespaces 2>/dev/null || true\` and flag any that are not Ready.
5. Summarise findings in this format:

## Triage ${DATE}

### CI Failures
<list or 'None'>

### Open Platform Issues
<list or 'None'>

### Flux Reconciliation Issues
<list or 'None'>

### Actionable Items
<numbered list of concrete next steps, each one sentence>

Write this summary to ${FINDINGS_FILE}. Do not open PRs or modify infrastructure — this is read-only triage only.
" \
  --allowedTools "Bash(gh run list *),Bash(gh issue list *),Bash(git log *),Bash(flux get *),Write(${STATE_DIR}/*)" \
  --output-format json 2>/dev/null)" || {
  echo "WARNING: claude -p failed during triage; check credentials and allowedTools." >&2
}

echo "Triage complete."

# Surface unresolved items to the triage inbox
if [[ -f "${FINDINGS_FILE}" ]]; then
  cp "${FINDINGS_FILE}" "${TRIAGE_DIR}/latest.md"
  echo "Findings written to ${FINDINGS_FILE} and ${TRIAGE_DIR}/latest.md"
else
  echo "WARNING: findings file was not produced — triage inbox not updated." >&2
fi
