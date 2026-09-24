# Skill: k8s-governance

Apply these rules whenever reading, writing, or reviewing Kubernetes manifests in this repo.

## Required Labels
Every workload (Deployment, StatefulSet, DaemonSet, Job, CronJob) must carry:

```yaml
labels:
  app.kubernetes.io/name: "<service-name>"
  app.kubernetes.io/version: "<semver>"
  app.kubernetes.io/component: "<frontend|backend|cache|worker>"
  app.kubernetes.io/part-of: "<product>"
  app.kubernetes.io/managed-by: "flux"
  platform.io/team: "<team>"
  platform.io/cost-centre: "<CC-XXXX>"
  platform.io/env: "<prod|staging|dev>"
```

Pods inherit workload labels via `spec.template.metadata.labels`. Both must be present.

## PodDisruptionBudget Rules
- Every Deployment with `replicas >= 2` must have a matching PodDisruptionBudget.
- Minimum available: `maxUnavailable: 1` or `minAvailable: N-1` (whichever keeps at least one pod up).
- PDBs must live in the same namespace as their target workload.
- PDBs named `<workload-name>-pdb`.

## Namespace Network Policy Defaults
Each namespace must have a default-deny ingress NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
```

Additional NetworkPolicies then selectively allow traffic. Never delete the default-deny.

## Istio mTLS Requirements
- Every namespace in `clusters/prod/` must have a `PeerAuthentication` set to `STRICT`.
- DestinationRules must not override to `DISABLE` without a documented exception ticket.
- Sidecar injection enabled via namespace label: `istio-injection: enabled`.
- Workloads must not set `sidecar.istio.io/inject: "false"` without an approved exception.

## Resource Requests and Limits
- CPU and memory requests are mandatory on all containers.
- Limits must be set for memory; CPU limits are recommended but may be omitted with justification.
- No `resources: {}` — this triggers a linting failure.
