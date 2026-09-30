#!/usr/bin/env bash
set -euo pipefail

# Reads CI failures, open issues, and recent commits; writes findings to state/triage-$(date).md
# Designed to run on a schedule (e.g. nightly cron or GitHub Actions schedule trigger).
# Each run is a fresh claude -p invocation — no accumulated context degradation.
#
# Architecture: Claude reads data and outputs findings as text. This script owns all file I/O.
# Write is intentionally absent from --allowedTools — Claude has no write access to the repo.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
TRIAGE_DIR="${REPO_ROOT}/triage"
DATE="$(date +%Y-%m-%d)"
FINDINGS_FILE="${STATE_DIR}/triage-${DATE}.md"

mkdir -p "${STATE_DIR}" "${TRIAGE_DIR}"

# Run claude -p and capture the JSON envelope. Claude outputs findings as its text response.
# This script extracts .result and writes it to disk — Claude never touches the filesystem.
if ! API_JSON=$(claude -p "
You are a triage automation running on the platform-loops repo.

0. Read previous state: run \`ls state/triage-*.md 2>/dev/null | sort | tail -1\`
   to find the most recent triage file. If it exists, cat it and note any unresolved
   actionable items in the 'Previous State' section of your output.
1. Read CI failures from the last 24h: run \`gh run list --limit 20 --json conclusion,name,url\` and identify any failures.
2. Read open issues labelled 'platform' or 'sre': run \`gh issue list --label platform,sre --json number,title,url,createdAt\`.
3. Read recent commits to main: run \`git log --oneline --since='24 hours ago'\`.
4. Run \`flux get kustomizations --all-namespaces 2>/dev/null || true\` and flag any that are not Ready.
5. Output your findings in the format below as your final response. Do not use the Write tool.

## Triage ${DATE}

### Previous State
<unresolved items carried forward from the previous triage file, or 'No previous triage file found — this is the first run.'>

### CI Failures
<list or 'None'>

### Open Platform Issues
<list or 'None'>

### Flux Reconciliation Issues
<list or 'None'>

### Recent Commits (last 24h)
<list or 'None'>

### Actionable Items
<numbered list of concrete next steps, each one sentence>

Do not open PRs or modify infrastructure — this is read-only triage only.
" \
  --allowedTools "Bash(ls state/*),Bash(cat state/*),Bash(gh run list *),Bash(gh issue list *),Bash(git log *),Bash(flux get *)" \
  --output-format json 2>&1); then
  echo "WARNING: claude -p failed during triage; check credentials." >&2
fi

# Extract Claude's text response and write the findings file
RESULT=$(echo "${API_JSON}" | jq -r '.result // empty' 2>/dev/null || true)
if [[ -n "${RESULT}" ]]; then
  echo "${RESULT}" > "${FINDINGS_FILE}"
fi

echo "Triage complete."

# Surface unresolved items to the triage inbox
if [[ -f "${FINDINGS_FILE}" ]]; then
  cp "${FINDINGS_FILE}" "${TRIAGE_DIR}/latest.md"
  echo "Findings written to ${FINDINGS_FILE} and ${TRIAGE_DIR}/latest.md"
else
  echo "WARNING: findings file was not produced — triage inbox not updated." >&2
fi
