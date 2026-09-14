---
id: SPEC-kube-deployment
companions: [glossary.md, infrastructure.md, tool-options.md, roadmap.md, defense-checklist.md]
sources: [../../../../kube-project.pdf]
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# KUBE — Kubernetes/GitOps Deployment of the Sample App

## Why

This is the Epitech "KUBE" module assignment: build a fully-equipped, production-style Kubernetes cluster on AWS and use it to host both infrastructure tooling and a converted application, graded against a fixed rubric (Objectives, Best practices, Security, Delivery, Defense, Bonuses). It is a mandate to meet, not a product to grow — the target application (this repo's Laravel sample app, currently run via docker-compose) is a fixed given; the work is entirely the surrounding cluster, GitOps pipeline, observability, and security around it. The user is new to Kubernetes, Docker, and AWS, so the path there needs to build concepts up rather than assume them — see `glossary.md`.

## Capabilities

- **CAP-1**
  - **intent:** Operator can stand up a fresh, reproducible Kubernetes cluster across the 3 provided AWS nodes with a single Ansible run.
  - **success:** Running the playbooks against a torn-down environment yields a working cluster with no manual steps.
- **CAP-2**
  - **intent:** Users can reach every exposed app and tool securely over HTTPS through a single ingress layer.
  - **success:** Every exposed hostname resolves via sslip.io/nip.io and serves a valid TLS certificate with no plaintext HTTP.
- **CAP-3**
  - **intent:** Operator can view and manage cluster workloads through a web dashboard instead of raw kubectl.
  - **success:** Dashboard shows live pod/deployment state and accepts basic management actions, reachable only after OIDC login.
- **CAP-4**
  - **intent:** Operator can observe system and application health through collected metrics and receive alerts on problems.
  - **success:** A dashboard shows live metrics for cluster and app, and a deliberately broken condition fires a visible alert.
- **CAP-5**
  - **intent:** Operator can search and visualize centralized logs from every workload.
  - **success:** A log query in the logging UI surfaces recent log lines from the app and from cluster components.
- **CAP-6**
  - **intent:** Operator can manage every reusable infrastructure component (ingress, dashboard, monitoring, logging, IdP, etc.) declaratively from Git, auto-reconciled into the cluster.
  - **success:** A change committed to the infra GitOps repo is applied to the cluster with no manual kubectl commands, and the operator UI shows it in sync.
- **CAP-7**
  - **intent:** The sample Laravel app, originally run via docker-compose, can be deployed to the cluster as a Helm chart, with its database deployed via the database's official chart.
  - **success:** `helm install`/`upgrade` of the app chart produces a running app connected to a running database.
- **CAP-8**
  - **intent:** Operator can deploy and update the application declaratively from its own GitOps repo, separate from the infra repo, with sync and health verified automatically.
  - **success:** A commit to the app GitOps repo triggers an automated deploy and the operator reports the app as synced and healthy.
- **CAP-9**
  - **intent:** Anyone accessing a deployed tool (Grafana, dashboard, GitOps operator UI, kubectl) or the Kubernetes API must authenticate via OIDC against a self-hosted identity provider.
  - **success:** An unauthenticated request to any covered tool or to the Kubernetes API is redirected to login, and a valid login grants access.
- **CAP-10**
  - **intent:** The cluster rejects requests that violate baseline policy (e.g. missing resource limits, missing mandatory labels, disallowed image registry) via a native admission policy.
  - **success:** A deliberately non-compliant manifest is rejected at apply time with a policy violation message.
- **CAP-11**
  - **intent:** The database's data survives pod restarts.
  - **success:** Deleting and recreating the DB pod leaves previously written data intact, backed by the shared EFS-backed PersistentVolume.
- **CAP-12**
  - **intent:** A scheduled job automatically performs a real operational task on a recurring basis.
  - **success:** The CronJob runs on schedule and its output (e.g. a backup artifact or report) is verifiable afterward.
- **CAP-13**
  - **intent:** Deploying a new app version never interrupts service, and a broken new version never receives live traffic.
  - **success:** During a rollout with a deliberately failing readiness probe, the app stays reachable throughout and only the previous healthy version serves requests.
- **CAP-14**
  - **intent:** Application images are published to and pulled from a private, authenticated registry rather than a public one.
  - **success:** The cluster pulls the app image using registry credentials, and the registry is not publicly readable.

## Constraints

- Cluster must be provisioned and deployed with Ansible so it can be torn down and rebuilt reproducibly (imposed).
- Admission control must use native `ValidatingAdmissionPolicy` (CEL-based), not a third-party policy engine (imposed).
- Authentication must use OIDC via dex, covering every deployed tool (Grafana, dashboard/Headlamp, GitOps operator, kubectl) plus the Kubernetes API itself, against a self-deployed identity provider such as Keycloak — no external corporate directory is available (imposed).
- All exposed endpoints must be served over HTTPS via cert-manager and Let's Encrypt (imposed).
- Application images must be published to and pulled from a private authenticated registry (imposed).
- Infra and application deployment must live in two separate GitOps repositories, kept cleanly separated.
- Only 3 AWS nodes are available: `kube-1` (control plane + worker, stable public IP that survives nightly shutdown — the entry point for DNS/TLS) and `kube-2`/`kube-3` (workers, unstable public IP, stable private VPC IP). See `infrastructure.md`.
- No load balancer or wildcard DNS is provided — ingress exposure must go through NodePort resolved via sslip.io or nip.io.
- All VMs auto-shutdown nightly and must be manually restarted — plan implementation and demo sessions around this.
- No plaintext secret may be committed to Git — sensitive data goes through Sealed Secrets or External Secrets into Kubernetes Secrets; everything else goes into ConfigMaps.
- Every resource must carry Kubernetes-recommended labels.
- Application containers need multiple replicas with anti-affinity so replicas of a service land on different nodes.
- Database persistent storage must use a PersistentVolume backed by the group's shared Amazon EFS; surviving a full cluster deletion is not required.
- Every workload must define CPU and RAM requests and limits.
- VM access is via AWS SSM Session Manager using school-email IAM Identity Center login, not VPN or public SSH; own SSH keys may be layered on top afterward.

## Non-goals

- No changes to the Laravel application's own code, routes, migrations, or business logic — it is a fixed given.
- Surviving a full cluster teardown is not required for persistent data, only surviving pod restarts.
- Integrating an external/corporate identity directory is out of scope — the IdP is self-hosted inside the cluster.
- The bonus items (see `defense-checklist.md`) are optional stretch goals, not required for the core deliverable.

## Success signal

A live defense demo where: Ansible provisions a fresh cluster from scratch; a new app version is deployed via a GitOps commit (not manual setup); the rollout keeps the app available throughout and a deliberately faulty version never receives traffic; and OIDC, HTTPS, and the admission policy are all visibly enforced. Full checklist in `defense-checklist.md`.

## Assumptions

- AWS/Kubernetes environment access will be granted before implementation phases begin, though it is not yet available as of 2026-09-14 — this blocks hands-on work but not planning.
- The application in scope is the existing Laravel sample app in this repo, currently run via docker-compose per its README.
- Specific tool choices among the suggested options (see `tool-options.md`) are decided later in the architecture phase (`bmad-architecture`), not finalized in this spec.

## Open Questions

- Ingress or Gateway API, and with which implementation — kubernetes-ingress with Nginx or Traefik, or Gateway API with Traefik or Envoy Gateway?
- Dashboard: kubernetes-dashboard or Headlamp?
- Monitoring stack: kube-prometheus or VictoriaMetrics?
- GitOps operator: ArgoCD or FluxCD?
- Secrets management: Sealed Secrets or External Secrets?
- Which bonus items, if any, will be pursued given time available?
