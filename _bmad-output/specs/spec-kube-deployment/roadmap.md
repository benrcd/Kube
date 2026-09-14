# Roadmap

A beginner-paced path through this project, ordered so each phase only depends on concepts and pieces already in place. Terms are defined in `glossary.md`; the imposed/suggested tool list is in `tool-options.md`; node/access details are in `infrastructure.md`.

Rough dependency chain: **0 → 1 → 2 → 3 → 4 → 5 → (6 and 7 in parallel) → 8 → 9 → 10**. Phases 6 and 7 can interleave since observability tools and the GitOps operator don't depend on each other, only on 4 (ingress/HTTPS) and 5 (auth) being in place so they can be exposed and protected correctly.

## Phase 0 — Learn the fundamentals (no cluster needed yet)

Get comfortable with Docker and core Kubernetes objects (Pod, Deployment, Service, ConfigMap, Secret — see `glossary.md`) using a local, disposable cluster (kind or minikube) on your own machine. Goal: be able to build an image, run it, and deploy something simple to a local cluster with `kubectl` before touching the real shared nodes.

## Phase 1 — Get access, do a dry run

Get AWS access (currently blocked — see `SPEC.md` assumptions) and confirm you can reach `kube-1/2/3` via SSM Session Manager. Do a first Ansible dry run that just confirms connectivity to all three nodes — no cluster yet. This is also when to confirm the EFS filesystem is visible from the instances.

## Phase 2 — Architecture decisions

Work through every "choose and justify" item in `tool-options.md` (Ingress vs Gateway API, dashboard, monitoring stack, GitOps operator, secrets tooling, IdP) and write down the reasoning — this doc is what you'll present as "the architecture of your infrastructure" during the defense. Use `bmad-architecture` for this.

## Phase 3 — Provision the cluster with Ansible

Write the Ansible playbooks that turn 3 bare AWS instances into a working Kubernetes cluster: `kube-1` as control plane + worker, `kube-2`/`kube-3` joined as workers. Success check: `kubectl get nodes` shows all 3, Ready, from a fresh run. This is the foundation the live demo opens with ("provisioning a fresh cluster with Ansible"), so get it reliable and reproducible early — rerun it a few times to prove it's repeatable, not a one-off.

## Phase 4 — Ingress/Gateway and HTTPS

Deploy the chosen ingress layer (Nginx/Traefik Ingress, or Gateway API) exposed via NodePort, wire up sslip.io/nip.io hostnames, and get cert-manager + Let's Encrypt issuing real TLS certificates. Do this before anything else gets exposed, since every later tool (dashboard, Grafana, ArgoCD/FluxCD UI, Keycloak) needs a working HTTPS hostname to sit behind.

## Phase 5 — Identity and access control

Deploy the self-hosted identity provider (e.g. Keycloak) and dex in front of it, then wire OIDC into `kubectl`/the Kubernetes API first (it's the trickiest integration and worth doing while the cluster is still simple). Add the native admission policy (`ValidatingAdmissionPolicy`) enforcing things like mandatory labels, resource limits, and allowed registries. The assignment brief explicitly calls out planning OIDC federation early — do this before layering on more tools that will also need to sit behind it.

## Phase 6 — Dashboard, monitoring, logging

Deploy the dashboard (kubernetes-dashboard or Headlamp), the monitoring stack (kube-prometheus or VictoriaMetrics) with alerting, and Loki for logs — each behind the ingress/HTTPS from Phase 4 and behind OIDC login from Phase 5.

## Phase 7 — GitOps for infrastructure

Move everything deployed so far into a Git repo organized with kustomize, and install the GitOps operator (ArgoCD or FluxCD) to reconcile it — so the infra repo becomes the source of truth and manual `kubectl apply`/`helm install` steps go away. This is a distinct repo from the application (Phase 8).

## Phase 8 — Convert and deploy the application

Package this repo's Laravel app as a Helm chart (app code itself stays untouched), use the database's official Helm chart, and set up: Secrets/ConfigMaps split, multiple replicas with anti-affinity, the EFS-backed PersistentVolume for the database, a CronJob for a real operational task (e.g. DB backup), and pushing the app image to the private registry. Create the separate application GitOps repo and get the GitOps operator deploying and reporting sync/health on it automatically.

## Phase 9 — Prove progressive, zero-downtime rollouts

Ship a deliberately broken version of the app (e.g. a failing readiness probe) through the GitOps pipeline and confirm the previous version keeps serving traffic throughout — this is a required part of the live demo. Tune readiness probes and the rollout strategy until this behaves correctly every time.

## Phase 10 — Documentation and defense prep

Write up cluster provisioning steps, container setup, and commands (mandatory per the brief). Rehearse the three-part defense: (1) cluster creation/config process, (2) infrastructure architecture, (3) GitOps application deployment process — plus the live demo checklist in `defense-checklist.md`. Only after the core is solid and rehearsed, consider bonus items from `tool-options.md` if time remains.

## Notes on pacing

- All VMs shut down nightly (`infrastructure.md`) — budget time each session to restart and re-verify the cluster before continuing new work.
- Since AWS access isn't available yet, Phases 0 and 2 (learning + architecture decisions) can proceed immediately; Phase 1 onward needs access.
- Once this roadmap is agreed, the natural next BMad steps are `bmad-architecture` (Phase 2) followed by `bmad-create-epics-and-stories` to turn these phases into trackable epics/stories, then `bmad-sprint-planning` and `bmad-build`.
