# Delivery and Defense Checklist

Source: `kube-project.pdf`, "Delivery," "Defense," and "Bonuses" sections.

## Delivery (what to hand in)

- [ ] Two Git repositories pushed: one for infrastructure components, one for the application (see `infrastructure.md` for the scope split).
- [ ] Ansible playbooks included in the delivery.
- [ ] Documentation covering, at minimum: cluster provisioning, container setup steps, and the commands used.

## Defense presentation — three parts

- [ ] **Cluster creation and configuration process** — show the responsibility of each component and the deployment of each building block.
- [ ] **Infrastructure architecture** — the overall design (see architecture doc once `bmad-architecture` runs).
- [ ] **GitOps application deployment process** — how a change goes from Git commit to running app.

## Live demonstration — required

- [ ] Provision a fresh cluster with Ansible, live.
- [ ] Deploy a new version of the application through the GitOps operator — a real Git commit reconciled automatically, or simple deployment commands — **not** a manual first-time setup.
- [ ] Show a progressive deployment: the app stays available throughout the rollout, and a faulty new version does not take over traffic (previous version keeps serving). Achieved via readiness probes and a rollout strategy that preserves the previous version; a canary/rollback tool is optional.
- [ ] Show evidence that OIDC authentication, HTTPS, and the admission policy are actually enforced (not just deployed).
- [ ] Enrich the demoed new version with a deliberate fault (e.g. a failing readiness probe) specifically to prove the rollout does not switch traffic to it.

## Bonuses (optional, pursue only after the core above is solid)

- [ ] Multi-tenancy and authentication for Prometheus and Loki via kube-rbac-proxy.
- [ ] An evaluation of Helm artefact security.
- [ ] Fine-grained orchestrator access permissions (RBAC).
- [ ] Reinforcement of network access (subject to infrastructure limitations).
- [ ] Lightweight Docker images.
- [ ] Zero-downtime deployment demonstrated with successful HTTP requests throughout (stronger proof than "stays available").
- [ ] Documented cluster upgrade process (version upgrade, node drain, component updates).
