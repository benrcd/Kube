# Glossary

Plain-language definitions for every term this project uses, written for someone new to Docker, Kubernetes, and AWS. Grouped roughly in the order you'll meet them.

## Containers and images

- **Docker image** — a packaged snapshot of an app plus everything it needs to run (code, runtime, libraries). Think "installer file" that always produces the exact same result.
- **Container** — a running instance of an image, isolated from the host machine, like a lightweight VM that starts in milliseconds.
- **Registry** — a server that stores images so machines can pull them down (Docker Hub is the public default). A **private authenticated registry** requires login to push or pull — this project must use one instead of a public registry.
- **docker-compose** — a tool to run several containers together (app + database) from one YAML file on a single machine. This project's app currently runs this way; the assignment is to move it onto Kubernetes instead.

## Kubernetes core

- **Kubernetes (k8s)** — a system that runs containers across multiple machines (nodes), restarting them if they crash, scaling them, and routing traffic to them.
- **Node** — one machine (VM) in the cluster. This project has 3: `kube-1`, `kube-2`, `kube-3` (details in `infrastructure.md`).
- **Control plane** — the "brain" of the cluster that makes scheduling and management decisions. Here it runs on `kube-1`, alongside worker duties.
- **Worker node** — a machine that actually runs your containers (called Pods). `kube-2` and `kube-3` are workers.
- **Pod** — the smallest deployable unit in Kubernetes: one or more containers that run together on the same node.
- **Deployment** — a Kubernetes object that manages a set of identical Pods (replicas), handling restarts and rolling out new versions.
- **Replica** — one copy of a running Pod. Multiple replicas = redundancy, so one Pod dying doesn't take the app down.
- **Affinity / anti-affinity rule** — a scheduling rule telling Kubernetes where Pods should (affinity) or should not (anti-affinity) run relative to each other — e.g. "don't put both replicas on the same node."
- **Namespace** — a way to partition a cluster into separate logical areas (e.g. `monitoring`, `app`) so resources don't collide.
- **Label** — a key/value tag attached to a resource (e.g. `app: myapp`) used to select, group, and organize resources. Kubernetes has recommended standard labels this project must follow.
- **ConfigMap** — stores non-sensitive configuration (e.g. a feature flag, a URL) that a Pod can read.
- **Secret** — like a ConfigMap but for sensitive data (passwords, API keys, tokens). Never commit these in plaintext to Git.
- **PersistentVolume (PV) / PersistentVolumeClaim (PVC)** — a PV is a piece of real storage (here, backed by AWS EFS) made available to the cluster; a PVC is a Pod's request to use some of that storage. Together they let data (like a database's files) survive a Pod restart.
- **CronJob** — a Kubernetes object that runs a task on a schedule (like a Unix cron job), e.g. a nightly backup.
- **Requests and limits** — per-container declarations of how much CPU/RAM a container needs (request) and the max it may use (limit). Required on every workload here.
- **Readiness probe** — a health check Kubernetes uses to decide if a Pod is ready to receive traffic. A failing readiness probe means the Pod is skipped for traffic — this is the mechanism used to prove a broken rollout doesn't go live.
- **Rolling update / progressive deployment** — replacing old Pods with new ones gradually rather than all at once, so the app stays available and a bad version can be caught before it replaces everything.

## Exposing apps

- **Service** — a stable network name/address in front of a set of Pods, so other things can reach them even as individual Pods come and go.
- **Ingress** — a Kubernetes object that routes external HTTP(S) traffic to internal Services based on hostname/path. Needs an **Ingress controller** (e.g. Nginx or Traefik) actually running in the cluster to work.
- **Gateway API** — a newer, more flexible alternative to Ingress for routing external traffic (via Traefik or Envoy Gateway here). This project picks one approach (Ingress or Gateway API), not both.
- **NodePort** — a way to expose a Service on a fixed port on every node's own IP, without a cloud load balancer. This project uses NodePort (via the ingress controller) because no load balancer is provided.
- **sslip.io / nip.io** — free DNS services that turn any IP address into a resolvable hostname automatically (e.g. `1.2.3.4` becomes `1-2-3-4.sslip.io`) — used here instead of a real registered domain.
- **TLS / HTTPS** — encrypts traffic between users and the cluster. **cert-manager** automates requesting and renewing TLS certificates from **Let's Encrypt** (a free certificate authority).

## GitOps and deployment tooling

- **Helm** — a package manager for Kubernetes: a "Helm chart" bundles all the YAML needed to install an app, with configurable values.
- **Kustomize** — a tool to customize plain Kubernetes YAML manifests without templating (overlays on a base), commonly used to organize a GitOps repo.
- **GitOps** — the practice of keeping the desired state of your cluster as files in a Git repo, with an operator continuously making the live cluster match Git — so "deploying" means "commit to Git," not "run a manual command."
- **GitOps operator** — the tool that watches a Git repo and applies changes to the cluster automatically (ArgoCD or FluxCD here). It also reports **sync** (does the cluster match Git?) and **health** (is the app actually working?) status.
- **Sync / Reconciliation** — the act of the GitOps operator applying the latest Git state to the live cluster.

## Security and identity

- **OIDC (OpenID Connect)** — a standard protocol for logging in via a central identity provider (like "Sign in with Google," but with your own provider here). Every tool in this project, plus the Kubernetes API itself, must require OIDC login.
- **Identity provider (IdP)** — the system that actually authenticates users (checks passwords, issues tokens). This project self-hosts one (e.g. Keycloak) since no external directory is provided.
- **dex** — a piece of software that sits between Kubernetes/your tools and an upstream IdP, translating logins into OIDC tokens those tools understand ("federation").
- **Admission policy / ValidatingAdmissionPolicy** — a rule Kubernetes checks *before* accepting a new or changed resource, written in **CEL** (Common Expression Language) — e.g. "reject any Pod without resource limits."
- **RBAC (Role-Based Access Control)** — Kubernetes' permission system: who (or what) is allowed to do what to which resources.
- **Sealed Secrets / External Secrets** — two different ways to keep real secret values out of Git: Sealed Secrets encrypts a Secret so only the cluster can decrypt it; External Secrets pulls real secret values in from an outside secret store at runtime.

## AWS pieces used here

- **EC2 instance** — a virtual machine in AWS; `kube-1/2/3` are EC2 instances.
- **EFS (Elastic File System)** — shared network storage that multiple instances can mount at once; backs this project's PersistentVolumes.
- **SSM Session Manager** — an AWS service for getting a terminal session on an EC2 instance through the AWS console/CLI, without needing SSH keys or a VPN.
- **IAM Identity Center** — AWS's system for signing users into AWS-connected tools (used here to log into SSM with a school email).
