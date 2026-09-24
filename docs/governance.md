# Platform Governance

This document describes the control framework for all infrastructure managed in `platform-loops`. It references skills by name for the detailed rules — see `.claude/skills/` for the authoritative source.

## Principles
1. Every change is reviewable, auditable, and reversible.
2. Prod changes require explicit human approval and a ticket.
3. Policy gates run before code runs — not after.
4. Secrets never live in version control.

---

## Tagging and Resource Ownership

All cloud resources must be tagged with `env`, `team`, `service`, `cost-centre`, `ticket`, and `managed-by`. The full tagging schema, enforcement approach, and checkov rules are defined in the **`terraform-conventions`** skill.

Resources without complete tags are blocked at plan time by checkov policy `CKV_CUSTOM_TAGGING`.

---

## Prod Change Controls

### Ticket Requirement
No command that modifies a `env=prod` resource or writes to `clusters/prod/` may proceed without a ticket reference. This is enforced by `.claude/hooks/block-prod-without-ticket.sh` (runs as a `PreToolUse` hook).

Ticket format: `[A-Z]+-[0-9]+` (e.g. `PLAT-1234`). The reference must appear in either the current git commit message or the `TICKET` environment variable.

### Policy Pass Gate
Writes to `clusters/prod/` are blocked until checkov and OPA policy checks have both passed in the current session. The gate is enforced by `.claude/hooks/require-policy-pass.sh`.

To clear the gate:
```bash
checkov -d clusters/prod/ --compact --quiet && \
opa eval -d policies/ -i plan.json "data.platform.deny" && \
touch .checkov-passed
```

The sentinel file expires after 30 minutes. Policy skip annotations require a justification comment and ticket reference — see the **`terraform-conventions`** skill.

### Kubernetes and Flux Rules
Label requirements, PodDisruptionBudgets, Istio mTLS settings, and NetworkPolicy defaults are defined in the **`k8s-governance`** skill.

Flux promotion flow (dev → staging → prod), Kustomization structure, and HelmRelease conventions are defined in the **`flux-conventions`** skill.

---

## Secret Scanning

`.claude/hooks/secret-scan-pre-commit.sh` runs on every pre-commit event. It uses `gitleaks` when available; otherwise falls back to grep-based pattern matching covering AWS keys, private keys, GitHub tokens, Slack tokens, JWTs, and generic `password`/`secret`/`token` assignments.

Any staged file containing a matched pattern blocks the commit. False positives may be annotated with `# gitleaks:allow` inline — this requires a peer review comment explaining why.

Secrets must be stored in AWS Secrets Manager and surfaced to workloads via ExternalSecrets operator. ConfigMaps must never contain credential values.

---

## Subagent Review Gates

Three subagent reviewers are available in `.claude/agents/` and should be invoked on relevant PRs:

| Agent | Trigger |
|-------|---------|
| `security-reviewer` | Any PR touching IAM, RBAC, environment variables, or network policy |
| `cost-reviewer` | Any PR touching Karpenter, EC2/EKS Terraform, or resource requests |
| `sre-verifier` | Any PR adding a new service or modifying `monitoring/` configs |

These agents read the diff and return structured findings. Their output must be addressed before the PR is merged.

---

## Loop Audit Trails

With a human writing every change, the git history is the audit trail. With agentic loops, the *run* is the audit trail — the plan output, checkov results, reviewer findings, and triage summaries. Git history alone is insufficient.

### Durable run output
Every governance-relevant loop writes its evidence to `state/` before the session ends. Files are named by loop type and timestamp (e.g. `state/pr-42-policy-2026-09-15T09:00:00.json`, `state/drift-2026-09-15T02:00:00.json`). Do not delete `state/` entries — they are the audit record.

### Triage inbox
`triage/latest.md` and `triage/drift-latest.json` are overwritten by each loop run with the most recent unresolved findings. Review and clear items from `triage/` before each scheduled run so findings do not silently accumulate.

### Verification debt
A loop running unattended is also making mistakes unattended. "Done" in a loop output is a claim, not a proof. The subagent review gate (see above) and the Stop hooks address this mechanically, but human review of `state/` output remains the final verification layer — especially for changes that "technically passed every check, but were still a bad idea."

### Loop observability
Monitor the loops themselves — not just what they produce. Track: how often `drift-detection.sh` exits 1, how often `sre-verifier` returns BLOCKED, how often a Stop hook fires. If a check never triggers, it may be misconfigured or too permissive. See `docs/observability-standards.md` for loop health metrics.

---

## Compliance References
- SOC 2 control mapping: `docs/soc2-control-map.md` (not yet written — ticket PLAT-9001)
- Data classification policy: internal wiki (link TBD)
- Change management policy: ITIL-aligned, tracked in Jira project `PLAT`
