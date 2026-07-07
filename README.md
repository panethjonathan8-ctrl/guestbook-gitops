# guestbook-gitops

Infrastructure-as-code and GitOps configuration for the `guestbook` app. This repo owns everything about **how and where** the app runs: AWS infrastructure (Terragrunt/Terraform), Kubernetes manifests (Helm), and continuous deployment (ArgoCD). Application source code lives in a separate repo, [`guestbook-app`](https://github.com/panethjonathan8-ctrl/guestbook-app) — see [Relationship to guestbook-app](#relationship-to-guestbook-app) below for why the two are split.

## Current state

Both EKS clusters (`guestbook-dev`, `guestbook-prod`) are **torn down** to avoid ongoing AWS cost between work sessions. VPCs are kept (free). Everything below describes the system as it exists in code and as it runs when deployed — bring an environment back with `terragrunt apply` per module (see [Bringing an environment up](#bringing-an-environment-up)).

## Architecture

```
AWS Account (eu-west-1)
   │
   ├─ Terragrunt/Terraform: VPC → EKS → { addons, argocd, rds }
   │
   └─ Inside each EKS cluster:
        AWS Load Balancer Controller, NGINX Ingress, External Secrets Operator, ArgoCD
              │
              └─ ArgoCD "app-of-apps": one seed Application fans out into
                 guestbook (per namespace), kube-prometheus-stack, loki, alloy, cluster-ingress
```

Two clusters, three environments:
- **`guestbook-dev`** cluster hosts two namespaces: `dev` and `staging`. They share this cluster (and even share one RDS instance, via two separate Secrets Manager secrets) because both are pre-production — low blast radius, not worth a second cluster.
- **`guestbook-prod`** cluster is fully isolated: its own cluster, RDS instance, IAM roles, and a real domain (`www.guestbookinterview.lol`) via Route53 + external-dns.

## Repo layout

```
infrastructure/
  root.hcl              # shared provider + S3 backend config, included by every module
  account.hcl            # account_id + region, single source of truth
  _envcommon/*.hcl       # per-module-type shared config (vpc, eks, addons, argocd, rds)
  live/{dev,prod}/       # per-environment: dependency wiring + env-specific overrides
  live/account/          # shared, not per-environment: dns, ecr, github-oidc
  modules/               # the actual Terraform (thin wrappers around registry modules
                          # for vpc/eks; hand-written for addons/argocd/rds/dns/github-oidc)
charts/
  guestbook/             # the application Helm chart (Deployment, Service, Ingress, HPA, PDB...)
  argocd-apps/           # the "app-of-apps" chart — one values file per env drives which
                          # Applications ArgoCD creates
  cluster-ingress/       # ALB ingress config (hostnames, ACM cert) per environment
  kube-prometheus-stack/ # Prometheus + Grafana, wrapper chart
  loki/                  # log aggregation, wrapper chart
  alloy/                 # ships logs to Loki + node metrics to Prometheus, wrapper chart
```

### Terragrunt DRY pattern

`root.hcl` → `_envcommon/<module>.hcl` → `live/<env>/<module>/terragrunt.hcl`. This is the standard Gruntwork-recommended layering: `root.hcl` generates the AWS provider and S3 backend once for every module; `_envcommon` holds each module type's shared "recipe" so dev and prod can't silently drift; each `live/<env>/<module>/terragrunt.hcl` is a thin file with just `dependency` blocks and the handful of inputs that actually differ per environment (instance sizing, feature flags).

Dependency graph: `vpc → eks → { addons, argocd, rds }`. The three siblings only depend on `vpc`/`eks` outputs, not each other — but on **destroy**, `eks` must always go last, since the siblings manage Kubernetes-API-backed resources that would be orphaned if the cluster disappeared first.

### ArgoCD app-of-apps

Terraform installs ArgoCD itself and exactly one `Application` (`app-of-apps`, pointed at `charts/argocd-apps`). Everything else — the guestbook app in each namespace, and every cluster-wide chart (monitoring stack, ingress config) — is created by ArgoCD itself, driven by one `values-<env>.yaml` file per environment. Adding a new environment or a new shared tool is a values-file entry, not a template change.

### Secrets

RDS credentials and OAuth client secrets live in AWS Secrets Manager. The External Secrets Operator (ESO), running in-cluster with an IRSA role scoped to specific `guestbook/<env>/*` prefixes, syncs them into real Kubernetes Secrets. The app and other pods never talk to Secrets Manager directly or hold AWS credentials — they only ever see a normal in-cluster Secret.

## Relationship to guestbook-app

`guestbook-app`'s CI builds a Docker image **once** per app-changing commit (tagged with the git short SHA) and pushes it to ECR — that's the only place a container image is ever built. Its CI/CD pipeline then commits a values-file change into *this* repo (e.g. bumping `charts/guestbook/values-dev.yaml`'s `image.tag`) and nudges ArgoCD to sync. Staging and prod are never rebuilt — when a release is cut, the exact same image digest is retagged with the semver version and promoted forward, so what runs in prod is guaranteed byte-identical to what was already validated in dev.

## Bringing an environment up

```
cd infrastructure/live/<env>/vpc && terragrunt apply
cd infrastructure/live/<env>/eks && terragrunt apply
cd infrastructure/live/<env>/addons && terragrunt apply
cd infrastructure/live/<env>/argocd && terragrunt apply
cd infrastructure/live/<env>/rds && terragrunt apply
```

Always run `terragrunt plan` first and review it — see `CLAUDE.md` for the full operating rules this project follows (never apply/destroy without explicit review, cost disclosure before creating resources, secret-scanning before every commit, issue-first workflow for every change).

## Known gaps

- No distributed tracing (Tempo) — metrics (Prometheus) and logs (Loki) only.
- No `NetworkPolicy` — pod-to-pod traffic inside a cluster is currently unrestricted. Scoped out for this project's size; would be the first thing added given more time.
- The `guestbook-dev` IAM user lacks `rds:CreateDBSnapshot`, which blocks a clean RDS destroy in prod (where `skip_final_snapshot=false`) unless the permission is granted or the flag is temporarily flipped. Documented directly in `infrastructure/live/prod/rds/terragrunt.hcl`.
