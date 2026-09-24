# Skill: observability-standards

Apply these rules whenever a new service is being added or reviewed. Every service that reaches staging must satisfy all items below before prod promotion.

## New Relic APM Configuration
Every service must ship with:
- APM agent configured via environment variables (not hardcoded licence key).
- `NEW_RELIC_APP_NAME` set to `<service>-<env>` (e.g. `payments-prod`).
- `NEW_RELIC_LICENSE_KEY` sourced from an ExternalSecret.
- Distributed tracing enabled: `NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true`.
- Log forwarding to New Relic enabled; structured JSON logs required.

## SLO Definitions
Each service must define at minimum:
- **Availability SLO**: 99.9% success rate over a 28-day rolling window.
- **Latency SLO**: 95th percentile response time < 500 ms over a 28-day rolling window.

SLOs are declared as New Relic Service Level objects (API or Terraform resource `newrelic_service_level`). The SLO definition must live in `monitoring/<service>/slo.tf`.

## SLO Dashboard Requirements
Every service must have a New Relic dashboard containing:
1. SLO burn rate (1h, 6h, 24h windows).
2. Golden signals: request rate, error rate, latency p50/p95/p99, saturation.
3. Deployment markers (linked to Flux HelmRelease events).
4. Infrastructure panel: pod count, CPU usage, memory usage.

Dashboard JSON must be committed to `monitoring/<service>/dashboard.json` and applied via Terraform.

## Alert Routing
- All alerts route through a PagerDuty service mapped to the owning team.
- Critical alerts (burn rate > 5x in 1h): page on-call immediately.
- Warning alerts (burn rate > 2x in 6h): Slack `#platform-alerts-<team>` only.
- Alert policy defined in `monitoring/<service>/alerts.tf`.

## NRQL Golden-Signal Patterns
```nrql
-- Request rate
SELECT rate(count(*), 1 minute) FROM Transaction WHERE appName = '<service>-prod'

-- Error rate
SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '<service>-prod'

-- Latency p95
SELECT percentile(duration, 95) FROM Transaction WHERE appName = '<service>-prod'

-- Saturation (pod CPU)
SELECT average(cpuPercent) FROM K8sContainerSample WHERE podName LIKE '<service>%' AND clusterName = 'prod'
```

See `docs/observability-standards.md` for rationale and thresholds.
