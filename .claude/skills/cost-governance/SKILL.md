# Skill: cost-governance

Apply these rules when reviewing or writing Terraform, Karpenter, or Kubernetes resource configurations.

## Approved Instance Type Families
| Workload Class       | Approved Families          | Notes                                      |
|----------------------|----------------------------|--------------------------------------------|
| General compute      | `m7i`, `m7g`               | Graviton preferred for cost                |
| Memory-optimised     | `r7i`, `r7g`               | For caches and analytics only              |
| CPU-optimised        | `c7i`, `c7g`               | CI runners, batch jobs                     |
| GPU                  | `g5`                       | ML inference only; requires approval       |
| Burstable            | `t3`, `t4g`                | Dev/staging non-critical paths only        |

Do not use previous-generation families (`m5`, `r5`, `c5`, etc.) for new deployments. Migrate existing uses on next service touch.

## Spot vs On-Demand Policy
- **Prod stateless workloads**: spot acceptable if `podDisruptionBudget` is configured and `topologySpreadConstraints` spreads across 3+ AZs.
- **Prod stateful workloads** (databases, Kafka, Elasticsearch): on-demand only.
- **Staging**: spot preferred for all workloads.
- **Dev**: spot only.

Sensitive namespaces (`payments`, `auth`, `compliance`): on-demand only regardless of environment; document the exception in the Karpenter NodePool comment.

## Karpenter NodePool Rules
Every NodePool must declare:
```yaml
spec:
  limits:
    cpu: "200"         # hard cap per NodePool
    memory: "800Gi"
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
  template:
    spec:
      expireAfter: 720h  # recycle nodes every 30 days
```

- `consolidationPolicy: WhenUnderutilized` is mandatory — never `WhenEmpty` in prod (too aggressive).
- NodePools must be scoped to a single team via `nodeClassRef` and node labels.
- No wildcard instance category selectors in prod; enumerate approved families explicitly.

## Consolidation Policy
- Enable Karpenter consolidation on all non-prod NodePools.
- Review weekly cost reports in `#platform-cost`; any week-over-week increase >10% triggers a cost-review PR.
- Committed spend: Reserved Instances or Savings Plans must cover at least 60% of baseline on-demand spend; review quarterly.
- Idle resource threshold: any deployment with <5% CPU and <10% memory utilisation over 7 days is flagged for rightsizing.
