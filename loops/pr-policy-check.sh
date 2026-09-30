#!/usr/bin/env bash
set -euo pipefail

# CI-triggered loop: runs terraform plan + checkov + OPA + posts PR comment.
# Usage: PR_NUMBER=<n> bash loops/pr-policy-check.sh
# Expected env: PR_NUMBER, AWS_PROFILE (or ROLE_ARN for CI)
#
# Architecture: Claude runs checks via Bash tools and outputs results as text.
# This script extracts .result from the JSON envelope and writes the log file.
# Write is intentionally absent from --allowedTools — Claude has no write access to the repo.
# Note: Bash(terraform *) allows shell redirects (e.g. terraform show -json > state/tfplan.json)
# which are needed to produce plan JSON for checkov/OPA. This is intentional.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
# Use dashes in the timestamp to avoid colon-in-filename issues on HFS+/NTFS
DATE="$(date +%Y-%m-%dT%H-%M-%S)"
PR_NUMBER="${PR_NUMBER:?PR_NUMBER must be set}"

mkdir -p "${STATE_DIR}"

LOG_FILE="${STATE_DIR}/pr-${PR_NUMBER}-policy-${DATE}.md"

if ! API_JSON=$(claude -p "
You are a policy-check automation for PR #${PR_NUMBER}.

Steps (run in order, stop and report on any failure):
1. Identify changed Terraform modules:
   \`git diff --name-only origin/main...HEAD | grep -E '\.tf$' | sed 's|/[^/]*\.tf$||' | sort -u\`
   Store this list as MODULES.

2. For each module directory in MODULES, run these commands using the module name as a
   unique suffix (e.g. tfplan-<module-basename>.json) so plans are never overwritten:
     terraform -chdir=<module> validate
     terraform -chdir=<module> plan -out=tfplan-<module>.binary
     terraform -chdir=<module> show -json tfplan-<module>.binary > ${STATE_DIR}/tfplan-<module>.json

3. For each tfplan-<module>.json produced:
   - Run \`checkov -f ${STATE_DIR}/tfplan-<module>.json --compact --quiet\` and capture exit code.
   - Run \`opa eval -d ${REPO_ROOT}/policies/ -i ${STATE_DIR}/tfplan-<module>.json 'data.platform.deny'\` and capture deny messages.
   - Flag any resource missing required tags: env, team, service, cost-centre, ticket, managed-by.

4. Aggregate all results across modules into a single PR comment with sections:
   Summary | Per-Module Terraform Plan | Checkov Results | OPA Results | Tag Compliance | Verdict (PASS / FAIL)
   Post the comment: \`gh pr comment ${PR_NUMBER} --body '<comment>'\`

5. Output the full aggregated results as your final response. Do not use the Write tool.

Do not run terraform apply.
" \
  --allowedTools \
    "Bash(git diff *),Bash(git log *),Bash(terraform *),Bash(checkov *),Bash(opa eval *),Bash(gh pr comment *)" \
  --output-format json 2>&1); then
  echo "WARNING: policy check claude -p failed." >&2
fi

# Extract Claude's response and write the log file
RESULT=$(echo "${API_JSON}" | jq -r '.result // empty' 2>/dev/null || true)
if [[ -n "${RESULT}" ]]; then
  echo "${RESULT}" > "${LOG_FILE}"
  echo "Policy check complete. Log: ${LOG_FILE}"
else
  echo "WARNING: no output produced — log file not written." >&2
fi
