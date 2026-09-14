# Infrastructure — Provided AWS Environment

Source: `kube-project.pdf`, "Infrastructure" section. Terms explained in `glossary.md`.

## Nodes

| Node | Role | Public IP | Private IP |
|---|---|---|---|
| `kube-1` | Control plane + worker | Stable — survives nightly shutdown; this is the project's entry point for DNS and TLS | Stable |
| `kube-2` | Worker | Unstable — changes on every restart; never build anything that depends on reaching it from outside | Stable |
| `kube-3` | Worker | Unstable — same as `kube-2` | Stable |

At least two workers are available specifically so high availability and anti-affinity rules can be demonstrated (replicas of a service must run on different nodes).

## Networking and exposure

- No dedicated load balancer and no wildcard DNS record are provided.
- Exposure goes through an Ingress controller reachable via **NodePort**, resolved through **sslip.io** (or **nip.io**) instead of a real domain.
- `kube-1`'s stable public IP is what keeps hostnames and TLS certificates valid day to day — it is the fixed point everything else hangs off.
- Since `kube-2`/`kube-3` have no fixed public IP, only their stable private VPC addresses should be relied on for node-to-node communication.

## Storage

- A shared **Amazon EFS** filesystem is provided to the group and can be mounted on the instances.
- Use it to back persistent storage (the database's PersistentVolume). Data must survive a database Pod restart; surviving a full cluster teardown is explicitly not required.

## Access

- VM access is through **AWS SSM Session Manager** (via the AWS console or AWS CLI) — sign in through the IAM Identity Center portal using your school email address.
- No SSH key is required to get in initially; once in, you're free to deploy your own SSH keys on top if that suits your provisioning approach better (e.g. for Ansible).

## Operational notes

- All VMs are automatically shut down every evening to conserve resources/cost, and can be restarted anytime. Plan implementation sessions and the live defense demo around this — verify the cluster/tools are back up after a shutdown before relying on them.
- The cluster must be provisioned and deployed via **Ansible**, so the whole environment can be torn down and rebuilt reproducibly from nothing — this is the mechanism demonstrated live during the defense ("provisioning a fresh cluster with Ansible").

## Repo scope separation

Keep two clearly separated scopes, each with its own GitOps repository:

1. **Infrastructure repo** — cluster components: ingress/gateway, dashboard, monitoring, logging, GitOps operator config, identity provider, admission policy, cert-manager, secrets tooling.
2. **Application repo** — the converted app: its Helm chart, database chart values, and the GitOps manifests that deploy it.
