#!/usr/bin/env bash
set -euo pipefail

# Scheduled loop: nightly drift detection across EKS, Aurora, and Cloudflare WAF.
# Designed for cron or GitHub Actions schedule; fresh context per run (Ralph-style).
#
# Architecture: Claude reads cluster/cloud state and outputs findings as JSON text.
# This script extracts .result from the JSON envelope and writes to disk.
# Write is intentionally absent from --allowedTools — Claude has no write access to the repo.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${REPO_ROOT}/state"
CLUSTERS_DIR="${REPO_ROOT}/clusters"
TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/prod"
# Use dashes in the timestamp to avoid colon-in-filename issues on HFS+/NTFS
DATE="$(date +%Y-%m-%dT%H-%M-%S)"
FINDINGS_FILE="${STATE_DIR}/drift-${DATE}.json"

mkdir -p "${STATE_DIR}"

if ! API_JSON=$(claude -p "
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
- If state/waf-baseline.json exists (check with \`cat state/waf-baseline.json\`),
  compare active WAF ruleset IDs against the baseline and flag additions or deletions.
  If the baseline does not exist, note that WAF baseline has not been captured yet.

## Deprecated API Check (EKS)
- Run \`kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis | grep -v '^#' || true\`
  and report any hits.

## Output
Output ONLY the following JSON object as your final response — no surrounding text, no code fences.
Set verdict to \"DRIFT_DETECTED\" if any surface shows drift, otherwise \"CLEAN\".
Do not use the Write tool.

{
  \"timestamp\": \"${DATE}\",
  \"eks\": { \"drifted\": false, \"findings\": [] },
  \"aurora\": { \"drifted\": false, \"findings\": [] },
  \"waf\": { \"drifted\": false, \"findings\": [] },
  \"deprecated_apis\": { \"found\": false, \"findings\": [] },
  \"verdict\": \"CLEAN\"
}

Do not modify any infrastructure.
" \
  --allowedTools \
    "Bash(kubectl get *),Bash(kubectl get --raw *),Bash(flux get *),Bash(aws rds describe-db-clusters *),Bash(aws rds describe-db-instances *),Bash(wrangler pages deployment list *),Bash(cat state/*),Bash(grep *)" \
  --output-format json 2>&1); then
  echo "WARNING: drift detection claude -p failed." >&2
fi

# Extract Claude's JSON response and write findings file
RESULT=$(echo "${API_JSON}" | jq -r '.result // empty' 2>/dev/null || true)
if [[ -n "${RESULT}" ]]; then
  echo "${RESULT}" > "${FINDINGS_FILE}"
  VERDICT=$(echo "${RESULT}" | jq -r '.verdict // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
else
  VERDICT="UNKNOWN"
fi

if [[ "${VERDICT}" == "DRIFT_DETECTED" ]]; then
  cp "${FINDINGS_FILE}" "${REPO_ROOT}/triage/drift-latest.json"
  echo "Drift detected — findings in triage/drift-latest.json"
  exit 1
else
  echo "No drift detected."
fi
