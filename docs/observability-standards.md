# Observability Standards

This document defines the observability requirements for all services running on the platform. Detailed implementation rules and NRQL patterns are in the **`observability-standards`** skill (`.claude/skills/observability-standards/SKILL.md`). This document covers rationale, thresholds, and the review process.

---

## Why These Standards Exist

Inconsistent observability is the primary reason incidents take too long to diagnose. These standards ensure every service provides the same minimum signal so on-call engineers can triage any service using the same mental model.

---

## Golden Signals

Every service must instrument and expose the four golden signals:

| Signal | Definition | Source |
|--------|-----------|--------|
| **Request rate** | Requests per minute received by the service | APM transaction data |
| **Error rate** | Percentage of requests returning 5xx or equivalent | APM error data |
| **Latency** | p50, p95, p99 response time | APM transaction data |
| **Saturation** | CPU and memory utilisation of the pod(s) | K8s infrastructure sample |

NRQL query patterns for each signal are provided in the **`observability-standards`** skill.

---

## SLO Definitions and Thresholds

| SLO Type | Target | Window | Breach Action |
|----------|--------|--------|---------------|
| Availability | 99.9% success rate | 28-day rolling | SEV2 if burn rate > 5x/1h |
| Latency | p95 < 500 ms | 28-day rolling | SEV3 if burn rate > 2x/6h |

Targets apply to all prod services by default. Services may request lower targets (e.g. internal tooling at 99.5%) by raising a `PLAT` ticket — the platform team approves exceptions quarterly.

Error budget burn rate thresholds follow the Google SRE multi-window alerting model:
- **Fast burn** (high urgency): burn rate > 5x over 1h AND > 5x over 5m → PagerDuty.
- **Slow burn** (low urgency): burn rate > 2x over 6h AND > 2x over 30m → Slack.

---

## New Relic Dashboard Requirements

Every service dashboard must contain these panels. See the **`observability-standards`** skill for the full widget specification.

1. SLO burn rate (1h, 6h, 24h windows side by side)
2. Request rate timeseries
3. Error rate timeseries with threshold line at 0.1%
4. Latency p50 / p95 / p99 timeseries
5. Pod count and HPA status
6. CPU usage per pod (stacked)
7. Memory usage per pod (stacked)
8. Deployment markers (linked to Flux HelmRelease events via New Relic change tracking)

Dashboard JSON must be committed to `monitoring/<service>/dashboard.json` and applied via the `newrelic_one_dashboard` Terraform resource.

---

## Alert Routing

Alerts are routed via New Relic notification channels to PagerDuty and Slack. The routing matrix:

| Severity | Condition | Destination |
|----------|-----------|-------------|
| Critical | Burn rate > 5x / 1h | PagerDuty service for owning team |
| Warning | Burn rate > 2x / 6h | `#platform-alerts-<team>` Slack |
| Info | Error rate > 0.1% sustained > 10m | `#platform-alerts-<team>` Slack |

Each team's PagerDuty service key and Slack channel are declared in `monitoring/teams.tf`. New teams must be added there before their first service goes to prod.

---

## Loop Health Observability

Once scheduled loops are running, monitor the loops themselves — not just the services they govern. An unmonitored loop drifts silently; a noisy loop generates findings nobody reads.

### Key signals per loop

| Loop | Signal to track | Alert condition |
|------|-----------------|-----------------|
| `drift-detection.sh` | Exit code / `verdict` in `state/drift-*.json` | DRIFT_DETECTED on 2+ consecutive runs without a triage ticket |
| `morning-triage.sh` | Count of actionable items in `state/triage-*.md` | > 10 unresolved items in triage/ after 48h |
| `pr-policy-check.sh` | Checkov/OPA exit code per PR log in `state/` | FAIL rate > 30% over rolling 7 days (signals a governance rule or workflow problem) |
| Stop hooks | Hook block count per session | Any session where a hook fires 5+ times (approaching the 8-block override limit) |
| `sre-verifier` | BLOCKED vs READY FOR PROD ratio | BLOCKED > 50% sustained → skill or checklist is miscalibrated |

### NRQL for loop health (New Relic custom events)

Loops that post findings to New Relic as custom events (event type `PlatformLoopRun`) can be queried:

```nrql
-- Drift detection hit rate (last 30 days)
SELECT count(*) FROM PlatformLoopRun
WHERE loop = 'drift-detection' AND verdict = 'DRIFT_DETECTED'
TIMESERIES 1 day SINCE 30 days ago

-- PR policy check failure rate
SELECT percentage(count(*), WHERE verdict = 'FAIL') FROM PlatformLoopRun
WHERE loop = 'pr-policy-check'
SINCE 7 days ago

-- Stop hook fire rate per session
SELECT count(*) FROM PlatformLoopRun
WHERE event_type = 'hook_block'
FACET hook_name SINCE 7 days ago
```

Instrument loop scripts to emit these events via `curl` against the New Relic Events API or via an MCP connector when available.

### Comprehension debt

The faster a loop ships changes, the wider the gap between what exists and what the team understands. Treat the `state/` directory as required reading, not an archive. Schedule a weekly 15-minute loop-review session: open `state/` entries from the past 7 days, confirm the findings match what landed in git, and flag anything that "technically passed every check" but looks wrong in hindsight.

---

## Pre-Prod Checklist

Before a new service is promoted to prod, the **`sre-verifier`** agent must confirm:

- [ ] APM agent configured (no hardcoded licence key)
- [ ] Distributed tracing enabled
- [ ] `monitoring/<service>/slo.tf` exists with availability and latency SLOs
- [ ] `monitoring/<service>/dashboard.json` applied via Terraform
- [ ] `monitoring/<service>/alerts.tf` defines critical and warning policies
- [ ] PodDisruptionBudget configured
- [ ] HPA configured with `minReplicas >= 2` in prod

The sre-verifier output (READY FOR PROD / BLOCKED) must be posted as a PR comment before merge.
