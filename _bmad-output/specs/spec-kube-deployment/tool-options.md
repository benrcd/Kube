# Tool Options

Source: `kube-project.pdf`. Everything below is a *suggestion* except the "Imposed" table — for suggested tools, pick one and be ready to justify the choice (this becomes the job of `bmad-architecture`). See `glossary.md` for what each tool does.

## Imposed (not optional)

| Area | Requirement |
|---|---|
| Cluster provisioning | Ansible |
| Admission control | Native `ValidatingAdmissionPolicy` (CEL-based) |
| Authentication | OIDC via dex |
| Transport security | HTTPS everywhere |
| Image registry | Private, authenticated |

## Suggested — choose and justify

| Capability | Option A | Option B |
|---|---|---|
| Traffic exposure | Kubernetes Ingress (Nginx or Traefik) | Gateway API (Traefik or Envoy Gateway) |
| Dashboard | kubernetes-dashboard | Headlamp |
| Monitoring stack | kube-prometheus | VictoriaMetrics |
| Logging stack | Loki (no suggested alternative given) | — |
| GitOps operator | ArgoCD | FluxCD |
| Secrets management | Sealed Secrets | External Secrets |
| Identity provider (behind dex) | Keycloak (suggested example) | any self-hosted IdP |

GitOps manifests for reusable infra components are organized with **kustomize** regardless of which operator is chosen. The application is packaged as a **Helm chart**, using the **official chart** for the database.

## Bonus / stretch tools

Optional, only if core objectives are solid first (full list and context in `defense-checklist.md`):

- kube-rbac-proxy — adds auth/multi-tenancy in front of Prometheus and Loki.
- RBAC — fine-grained orchestrator access permissions.
- Network policies — reinforce network access between workloads.
- Lightweight base images for the app's Docker image.
- Canary/rollback tooling (e.g. Argo Rollouts/Flagger) for zero-downtime deployment beyond basic rolling updates.

## Open decisions

Every "choose and justify" row above is currently an open question in `SPEC.md`. Recommend resolving these during the `bmad-architecture` step, where each choice can be documented alongside its reasoning for the defense presentation.
