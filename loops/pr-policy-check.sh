#!/usr/bin/env bash
set -euo pipefail

# CI-triggered loop: runs terraform plan + checkov + cost estimate + posts PR comment.
# Usage: PR_NUMBER=<n> bash loops/pr-policy-check.sh
# Expected env: PR_NUMBER, AWS_PROFILE (or ROLE_ARN for CI)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
# Use dashes in the timestamp to avoid colon-in-filename issues on HFS+/NTFS
DATE="$(date +%Y-%m-%dT%H-%M-%S)"
PR_NUMBER="${PR_NUMBER:?PR_NUMBER must be set}"

mkdir -p "${STATE_DIR}"

LOG_FILE="${STATE_DIR}/pr-${PR_NUMBER}-policy-${DATE}.json"

# Claude writes the structured LOG_FILE directly via its Write tool.
# The raw API response envelope is captured separately to avoid overwriting it.
API_RESPONSE_FILE="${STATE_DIR}/pr-${PR_NUMBER}-api-${DATE}.json"

claude -p "
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

5. Write the full aggregated structured output to ${LOG_FILE}.

Do not run terraform apply.
" \
  --allowedTools \
    "Bash(git diff *),Bash(git log *),Bash(terraform *),Bash(checkov *),Bash(opa eval *),Bash(gh pr comment *),Write(${STATE_DIR}/*)" \
  --output-format json > "${API_RESPONSE_FILE}"

echo "Policy check complete. Log: ${LOG_FILE}"
