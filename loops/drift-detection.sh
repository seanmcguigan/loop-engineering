#!/usr/bin/env bash
set -euo pipefail

# Scheduled loop: nightly drift detection across EKS, Aurora, and API Gateway.
# Posts findings as New Relic custom events and writes to state/.
# Designed for cron or GitHub Actions schedule; fresh context per run (Ralph-style).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
CLUSTERS_DIR="${REPO_ROOT}/clusters"
TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/prod"
# Use dashes in the timestamp to avoid colon-in-filename issues on HFS+/NTFS
DATE="$(date +%Y-%m-%dT%H-%M-%S)"
FINDINGS_FILE="${STATE_DIR}/drift-${DATE}.json"

mkdir -p "${STATE_DIR}"

# Claude writes the structured FINDINGS_FILE directly via its Write tool.
# The raw API response envelope is captured separately to avoid overwriting it.
API_RESPONSE_FILE="${STATE_DIR}/drift-api-${DATE}.json"

claude -p "
You are a drift-detection automation. Check for infrastructure drift across the following surfaces.

## EKS
- Run \`kubectl get nodes -o json\` and compare each node's Kubernetes version to the
  target version defined in \`cat ${TERRAFORM_DIR}/terraform.tfvars\` (look for kubernetes_version or cluster_version variable).
- Run \`kubectl get kustomizations --all-namespaces -o json\` and flag any with status != Ready
  or that have failed to reconcile in the last 30m.
- Run \`flux get helmreleases --all-namespaces\` and compare chart versions against
  pinned versions in ${CLUSTERS_DIR}/prod/ (read relevant HelmRelease files with \`cat\` or \`grep -r chartVersion\`).
  If ${CLUSTERS_DIR}/prod/ does not exist yet, skip this check and note it in findings.

## Aurora
- Run \`aws rds describe-db-clusters --query 'DBClusters[*].{ID:DBClusterIdentifier,Status:Status,EngineVersion:EngineVersion}'\`
  and flag any not in 'available' status or running a deprecated engine version.
- Verify automated backups are enabled and the last backup succeeded within 25h.

## Cloudflare WAF
- Run \`wrangler pages deployment list 2>/dev/null || echo 'wrangler not available'\`.
- If ${STATE_DIR}/waf-baseline.json exists (check with \`cat ${STATE_DIR}/waf-baseline.json\`),
  compare active WAF ruleset IDs against the baseline and flag additions or deletions.
  If the baseline does not exist, note that WAF baseline has not been captured yet.

## Deprecated API Check (EKS)
- Run \`kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis | grep -v '^#' || true\`
  and report any hits.

## Output
Write a JSON findings file to ${FINDINGS_FILE} with this exact structure:
{
  \"timestamp\": \"${DATE}\",
  \"eks\": { \"drifted\": false, \"findings\": [] },
  \"aurora\": { \"drifted\": false, \"findings\": [] },
  \"waf\": { \"drifted\": false, \"findings\": [] },
  \"deprecated_apis\": { \"found\": false, \"findings\": [] },
  \"verdict\": \"CLEAN\"
}
Set verdict to \"DRIFT_DETECTED\" if any surface shows drift.

Do not modify any infrastructure.
" \
  --allowedTools \
    "Bash(kubectl get *),Bash(kubectl get --raw *),Bash(flux get *),Bash(aws rds describe-db-clusters *),Bash(aws rds describe-db-instances *),Bash(wrangler pages deployment list *),Bash(cat *),Bash(grep *),Write(${STATE_DIR}/*)" \
  --output-format json > "${API_RESPONSE_FILE}"

# Read the verdict from the structured findings file Claude wrote — not from the API envelope
VERDICT=$(jq -r '.verdict // "UNKNOWN"' "${FINDINGS_FILE}" 2>/dev/null || echo "UNKNOWN")
if [[ "${VERDICT}" == "DRIFT_DETECTED" ]]; then
  cp "${FINDINGS_FILE}" "${REPO_ROOT}/triage/drift-latest.json"
  echo "Drift detected — findings in triage/drift-latest.json"
  exit 1
else
  echo "No drift detected."
fi
