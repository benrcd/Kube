# Sample App — Local Development and Kubernetes

Local setup for the Epitech KUBE project: running the Laravel sample app in
Docker, and deploying it to a local Kubernetes cluster with `kind`.

The application source is a fixed given and is not modified. Everything here
is packaging and deployment.

---

## Contents

- [Requirements](#requirements)
- [Running with Docker Compose](#running-with-docker-compose)
- [Running on Kubernetes with kind](#running-on-kubernetes-with-kind)
- [Inspecting and debugging](#inspecting-and-debugging)
- [Common tasks](#common-tasks)
- [Known environment issues](#known-environment-issues)
- [Application notes](#application-notes)

---

## Requirements

- Docker Desktop
- `kind` and `kubectl` for the Kubernetes workflow

```powershell
winget install Kubernetes.kind
winget install Kubernetes.kubectl
```

---

## Running with Docker Compose

For day-to-day work on the app itself. Compose is **local development only** —
it is replaced entirely by Kubernetes manifests for deployment.

```bash
docker compose up -d --build
```

The schema comes from Laravel migrations, which are not run automatically.
On a fresh database (first run, or after `down -v`):

```bash
docker compose exec app php artisan migrate --force
```

`--force` is required because `APP_ENV=production` makes Laravel prompt for
confirmation and there is no terminal to answer.

The app is then on <http://localhost:8081>.

To see actual exception traces (the committed config runs with debug off):

```bash
docker compose run --rm -e APP_DEBUG=true -e APP_ENV=local -p 8081:80 app
```

Tear down, including the database volume:

```bash
docker compose down -v
```

---

## Running on Kubernetes with kind

### 1. Create the cluster

```bash
kind create cluster --name kube-learning --image kindest/node:v1.31.0
```

> The node image is pinned deliberately. See
> [Known environment issues](#known-environment-issues).

Verify:

```bash
kubectl get nodes          # expect one node, Ready
kubectl get pods -A        # -A = all namespaces; shows the control plane
```

### 2. Build and load the image

```bash
docker build -t laravel-app:v1 .
kind load docker-image laravel-app:v1 --name kube-learning
```

> **The load step is not optional.** The cluster runs its own container
> runtime and cannot see images in your local Docker. Skipping it produces
> `ErrImagePull` even though `docker images` clearly shows the image.
> Re-run it after every rebuild.

Confirm it arrived:

```bash
docker exec kube-learning-control-plane crictl images | findstr laravel
```

### 3. Deploy

Apply in order — later objects reference the namespace, and the app expects
the database to exist.

```bash
kubectl apply -f k8s/00-namespace.yaml

# Saves typing -n sample-app on every later command
kubectl config set-context --current --namespace=sample-app

kubectl apply -f k8s/01-config.yaml
kubectl apply -f k8s/02-mysql.yaml
kubectl get pods -w                      # wait for 1/1, then Ctrl+C
```

MySQL's first boot initialises the data directory and takes a minute or two.
`0/1 Running` means the container started but the readiness probe has not
passed yet.

```bash
kubectl apply -f k8s/03-migrate-job.yaml
kubectl logs job/app-migrate             # should show the five migrations

kubectl apply -f k8s/04-app.yaml
kubectl get pods -w                      # wait for both pods 1/1
```

### 4. Access it

```bash
kubectl port-forward service/app 8080:80
```

Then <http://localhost:8080>. The command holds the tunnel open in the
foreground; `Ctrl+C` to stop.

### 5. Tear down

```bash
kubectl delete namespace sample-app      # just the app
kind delete cluster --name kube-learning # the whole cluster
```

---

## Inspecting and debugging

```bash
kubectl get pods
kubectl get all                          # everything in the namespace

# Which pod IPs a Service currently routes to.
# EMPTY = the Service selector matches nothing. This is the single most
# common failure and it produces no error message anywhere.
kubectl get endpoints mysql

# The Events section at the bottom explains scheduling failures,
# image pull errors and probe failures.
kubectl describe pod <name>

kubectl logs <pod>
kubectl logs <pod> --previous            # a container that already crashed
kubectl logs -f job/app-migrate          # -f follows

kubectl get events --sort-by=.lastTimestamp
```

Pod status meanings worth knowing:

| Status | Meaning |
|---|---|
| `ContainerCreating` | Scheduled; pulling the image, mounting volumes |
| `Init:0/1` | An initContainer is still running |
| `0/1 Running` | Container up, readiness probe not passing yet |
| `1/1 Running` | Ready and receiving traffic |
| `Completed` | Ran to completion — normal for a Job |
| `ErrImagePull` | Usually a missing `kind load` |
| `OOMKilled` | Exceeded its memory limit |

---

## Common tasks

### The rebuild loop

```bash
docker build -t laravel-app:v2 .
kind load docker-image laravel-app:v2 --name kube-learning
kubectl set image deployment/app app=laravel-app:v2
kubectl rollout status deployment/app
```

> **Use a new tag every time.** With `imagePullPolicy: IfNotPresent`,
> reusing `v1` means Kubernetes keeps the old image even after you reload it,
> and your changes silently do not appear. Incrementing the tag is also the
> habit required for GitOps, where the tag change *is* the deployment.

### Re-running migrations

A Job's pod template is immutable, so it must be deleted before re-applying.
`migrate --force` is a no-op on an already-migrated database, so this is safe
to repeat.

```bash
kubectl delete job app-migrate
kubectl apply -f k8s/03-migrate-job.yaml
```

### Rollouts

```bash
kubectl rollout restart deployment/app   # force a rollout with no change
kubectl rollout status deployment/app
kubectl rollout undo deployment/app      # back to the previous version
```

### Verify data survives a pod restart

```bash
kubectl delete pod -l app.kubernetes.io/name=mysql
kubectl get pods -w
```

A replacement appears within seconds because the Deployment controller
notices the replica count is wrong. Reload the app — the counter value is
still there, because the PersistentVolumeClaim outlived the pod.

### After a Docker or laptop restart

```bash
docker ps -a --filter name=kube-learning
docker start kube-learning-control-plane
```

If `kubectl` then reports a connection refused, the container's published
port changed. Rewrite the kubeconfig:

```bash
kind export kubeconfig --name kube-learning
```

---

## Known environment issues

### cgroup v1 (Windows / WSL2)

Docker Desktop on this setup provides cgroup **v1**. Kubernetes 1.37's
kubelet does not work with it: `kubeadm init` writes all its certificates and
manifests successfully, then fails with `dial tcp ...:6443: connection
refused` because the control plane containers never start.

Check with:

```bash
docker info | findstr -i cgroup
```

Two options:

1. **Pin an older node image** (what this README uses). Kubernetes 1.31 still
   supports cgroup v1. No downside for learning — none of the objects used
   here differ between versions.

   ```bash
   kind create cluster --name kube-learning --image kindest/node:v1.31.0
   ```

2. **Switch WSL to cgroup v2.** Create `C:\Users\<you>\.wslconfig`:

   ```ini
   [wsl2]
   kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
   ```

   Then `wsl --shutdown` and restart Docker Desktop.

This does not affect the AWS nodes, which run a normal Linux kernel with
cgroup v2 by default.

### Wedged containerd

Symptom: `kubectl` returns `Unable to connect to the server: EOF`, the node
container looks healthy in `docker ps`, and CPU sits high.

Confirm by running a command that should be instant:

```bash
docker exec kube-learning-control-plane crictl ps -a
```

If it hangs, containerd inside the node is stuck. Restart the node:

```bash
docker restart kube-learning-control-plane
```

If that does not help, recreate the cluster. Nothing is lost — the manifests
are the source of truth.

A VPN client with network filtering (NordVPN and similar) is a plausible
cause, as they install filter drivers that interfere with Docker and WSL
networking. Worth quitting it entirely as a first test.

---

## Application notes

Things about this Laravel app that shape its deployment. None require code
changes; all are environment variables.

| Variable | Why |
|---|---|
| `LOG_CHANNEL=stderr` | By default Laravel writes to `storage/logs/laravel.log` inside the container, where no log collector will find it. Loki reads pod stdout/stderr. |
| `SESSION_DRIVER=cookie` | The default `file` driver stores sessions on local disk, so with multiple replicas a session exists on exactly one pod. The cookie driver needs no table and no Redis. |
| `APP_KEY` | Must be identical across all replicas or encrypted sessions and cookies break. It is a secret, not config. |
| `APP_ENV` / `APP_DEBUG` | Debug mode renders full stack traces including environment variables on any error page. |

**Schema** comes from Laravel migrations (`database/migrations/`), not from
init SQL. The `mysql-init/` directory referenced by the original compose file
was empty and has been removed.

**Migrations must run exactly once per deploy**, never once per replica.
Hence the `Job` in `k8s/03-migrate-job.yaml`, which becomes a Helm hook in
the application chart. An initContainer would run per-replica and race.

**The health endpoint** is `/healthz.html`, a static file created at image
build time. It deliberately does not touch the database: a readiness probe
that tested a shared dependency would mark every replica unready during any
database blip and turn a degraded service into a total outage.

### Deliberately left out of the local setup

Present in the real deployment, omitted here and why:

- **Pod anti-affinity** — required on AWS so replicas land on different
  nodes. With one kind node it would leave the second pod unschedulable.
- **Sealed Secrets** — `k8s/01-config.yaml` contains plaintext secrets and
  **must not be committed**. The real deployment commits an encrypted
  `SealedSecret` instead.
- **Ingress and TLS** — the app Service stays `ClusterIP`; an ingress
  controller terminates TLS in front of it. Locally, `port-forward` replaces
  that.
- **`STOPSIGNAL SIGWINCH`** — Apache treats `SIGTERM` as an immediate stop,
  killing in-flight requests; `SIGWINCH` is the graceful signal. Needed for
  the zero-downtime objective.
