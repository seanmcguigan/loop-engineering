# Skill: flux-conventions

Apply these rules whenever reading, writing, or reviewing Flux CD configuration in this repo.

## Kustomization Structure
```
clusters/
  dev/
    flux-system/        # Flux bootstrap output — do not hand-edit
    apps/               # Kustomization CRs pointing at base + dev overlay
    infra/              # Kustomization CRs for infra components
  staging/
    ...
  prod/
    ...
base/
  apps/
    <service>/
      kustomization.yaml
      deployment.yaml
      service.yaml
      ...
  infra/
    <component>/
      kustomization.yaml
      ...
```

Every `Kustomization` CR must set:
- `spec.prune: true` — orphaned resources are removed.
- `spec.wait: true` — flux waits for all resources to be ready.
- `spec.timeout: 5m` — fail fast; increase only with justification.

## Promotion Flow
Promotion is always `dev → staging → prod`. Never skip an environment.

1. Merge to `main` triggers reconciliation in `dev` automatically.
2. Staging promotion: open a PR updating the image tag in `clusters/staging/apps/<service>/` and get one peer approval.
3. Prod promotion: open a PR for `clusters/prod/`, attach the staging diff, require two approvals + a ticket reference in the PR title.

Image tags must be semver (`v1.2.3`). No `latest`, no branch tags in staging or prod.

## Required Health Checks
Every `Kustomization` in `clusters/prod/` must reference a `healthChecks` list that covers:
- The Deployment/StatefulSet itself (readiness).
- Any associated HorizontalPodAutoscaler.
- Any associated HelmRelease.

Example:
```yaml
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-service
      namespace: my-namespace
```

## HelmRelease Conventions
- `spec.chart.spec.version` must be a semver range (`>=1.2.0 <2.0.0`) or an exact pin.
- `spec.upgrade.remediation.retries: 3` — prevent infinite loops.
- `spec.rollback.cleanupOnFail: true`.
- Values files live at `clusters/<env>/apps/<service>/values.yaml`; secrets via `valuesFrom` referencing a SealedSecret or ExternalSecret.
