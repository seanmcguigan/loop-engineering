# Skill: incident-runbook

Load this skill when responding to or investigating a live incident. Follow these steps in order.

## Severity Levels
| SEV | Definition                                     | Response Time |
|-----|------------------------------------------------|---------------|
| 1   | Complete service outage or data loss           | Immediate     |
| 2   | Significant degradation, >10% error rate       | 15 min        |
| 3   | Partial degradation, SLO burn elevated         | 1 hour        |
| 4   | Minor issue, no SLO impact                     | Next business day |

## Response Steps

### 1. Acknowledge and Declare
- Acknowledge the PagerDuty alert within 5 minutes (SEV1/2) or 30 minutes (SEV3).
- Create an incident channel: `#inc-<YYYYMMDD>-<short-description>`.
- Assign an Incident Commander (IC) and a Comms Lead.
- Post the incident doc link in the channel (template: `docs/incident-template.md`).

### 2. Triage — First 10 Minutes
```bash
# Check pod health across prod
kubectl get pods -A --field-selector=status.phase!=Running | grep -v Completed

# Check recent Flux reconciliation failures
flux get kustomizations -A | grep -v True

# Check recent deployments (last 30 min)
kubectl rollout history deployment -A --revision=0 2>/dev/null | tail -20

# Pull error rate for the past 5 minutes (NRQL — run in New Relic)
# SELECT percentage(count(*), WHERE error IS true) FROM Transaction
# WHERE appName LIKE '%-prod' SINCE 5 minutes ago FACET appName
```

### 3. Contain
- If a recent deployment is the cause: `flux suspend kustomization <name> -n flux-system` then rollback.
- If infra: isolate affected nodes — cordon then drain before terminating.
- Engage the owning team's on-call if the issue is application-layer.

### 4. Communicate
- SEV1/2: post updates to `#incidents` every 15 minutes.
- SEV3: post updates every hour.
- External status page: update `status.platform.example.com` for any customer-visible impact.

### 5. Resolve and Follow Up
- Confirm SLO burn rate has returned to baseline before closing.
- Write a blameless post-mortem within 3 business days (SEV1/2) or 5 days (SEV3).
- Open follow-up tickets tagged `incident-followup` in Jira.
- Post-mortem reviewed in the next platform weekly.

## Common Runbooks
- **OOMKilled pods**: check `kubectl top pods`, adjust memory limits, check for memory leaks.
- **CrashLoopBackOff**: `kubectl logs <pod> --previous`, check config/secret mounts.
- **Flux stuck reconciling**: `flux logs --level=error`, check GitRepository source status.
- **High latency**: check Istio telemetry, New Relic traces, DB slow query logs.
- **Certificate expiry**: check cert-manager `Certificate` objects for `Ready: False`.
