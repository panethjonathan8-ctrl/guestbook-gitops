terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# The Helm provider speaks directly to the EKS API server.
# It authenticates using a short-lived token fetched by the AWS CLI —
# the same mechanism kubectl uses with aws eks update-kubeconfig.
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

# Install ArgoCD itself from the official Helm chart.
# wait = true blocks until all ArgoCD pods pass their readiness probes,
# so the next resource (argocd_apps) never tries to create an Application
# before the Application CRD exists.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  # server.insecure tells argocd-server to serve plain HTTP instead of its
  # default self-signed HTTPS. That's safe here specifically because TLS is
  # already terminated once, upstream, at the ALB (see charts/cluster-ingress)
  # — everything past that point (ALB->NGINX->argocd-server) stays inside the
  # cluster's private network. Without this, NGINX would fail to reach
  # argocd-server at all: it proxies plain HTTP to the backend by default,
  # and argocd-server's self-signed cert would reject that connection.
  #
  # Prod-only (enable_sso defaults to false) — dev keeps ArgoCD's default
  # settings since it has no Ingress or public hostname pointed at it.
  values = var.enable_sso ? [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }

        # "url" tells argocd-server its own externally-reachable base URL.
        # Dex uses this to build the OAuth redirect/callback URL it sends to
        # GitHub — without it, Dex would guess based on the request it
        # received, which breaks behind a reverse proxy like our ALB/NGINX.
        cm = {
          url = "https://${var.sso_hostname}"

          # Dex is ArgoCD's bundled identity broker — it's what actually
          # redirects the browser to GitHub and handles the callback. No
          # "orgs:" filter here: panethjonathan8-ctrl is a personal GitHub
          # account, not an organisation, so there's no org membership to
          # check. Anyone with a GitHub account can *authenticate* — RBAC
          # below is what decides whether that identity gets any real
          # *access*, which is the deny-by-default gate that matters.
          "dex.config" = yamlencode({
            connectors = [
              {
                type = "github"
                id   = "github"
                name = "GitHub"
                config = {
                  clientID     = "$dex.github.clientID"
                  clientSecret = "$dex.github.clientSecret"
                }
              }
            ]
          })
        }

        # RBAC is the authorization layer: Dex above only answers "who is
        # this?"; this decides "what are they allowed to do?". Deny-by-default
        # (policy.default = "") means every GitHub login gets zero access
        # unless explicitly listed — only sso_admin_email gets role:admin.
        #
        # Matched on email, not the GitHub username: Dex's GitHub connector
        # returns an opaque sub claim (not the readable login) and no groups
        # claim (no org configured, since this is a personal account), so
        # email is the only claim ArgoCD's RBAC can reliably match an
        # individual SSO user against. Confirmed via argocd-server's own
        # request logs on a real login — matching on the username here
        # silently granted zero access despite logging in as the right person.
        #
        # The built-in admin *password* login (separate from GitHub SSO) still
        # bypasses this file entirely, which is why it remains a valid fallback.
        rbac = {
          "policy.default" = ""
          "policy.csv"     = "g, ${var.sso_admin_email}, role:admin"
        }
      }
    })
  ] : []
}

# Create the bootstrap Application using the official argocd-apps Helm chart.
# This chart's only job is to create Application CRs — it is not ArgoCD itself.
# The Application it creates ("app-of-apps") points back at this gitops repo
# so ArgoCD can discover and sync all other applications from there.
resource "helm_release" "argocd_apps" {
  depends_on = [helm_release.argocd]

  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = var.argocd_namespace
  wait       = true

  # argocd-apps chart v2.0.0+ changed applications from a list to a map.
  # The map key becomes metadata.name — using a list produced numeric indices
  # as names, causing "cannot unmarshal number into metadata.name".
  values = [
    yamlencode({
      applications = {
        "app-of-apps" = {
          namespace = var.argocd_namespace
          project   = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.gitops_repo_branch
            path           = "charts/argocd-apps"
            helm = {
              valueFiles = ["values-${var.env_name}.yaml"]
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.argocd_namespace
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# External Secrets Operator (ESO)
# ---------------------------------------------------------------------------

# Extract the bare OIDC provider URL from the ARN so we can use it as the
# condition key in the trust policy. The ARN format is:
#   arn:aws:iam::<account>:oidc-provider/<url>
# We need just the <url> part for the StringEquals condition.
locals {
  oidc_provider_url = replace(
    var.oidc_provider_arn,
    "arn:aws:iam::${var.account_id}:oidc-provider/",
    ""
  )

  # When eso_secret_name_prefixes is empty, fall back to the environment's own
  # prefix. This keeps single-environment clusters (prod) simple — no override
  # needed. Multi-environment clusters (dev hosting dev+staging) pass an
  # explicit list so the IAM policy covers all required paths.
  resolved_eso_prefixes = length(var.eso_secret_name_prefixes) > 0 ? var.eso_secret_name_prefixes : ["guestbook/${var.env_name}"]
}

# IAM role ESO assumes via IRSA (IAM Roles for Service Accounts).
#
# How IRSA works:
#   1. ESO runs in Kubernetes with a service account annotated with this role ARN.
#   2. EKS projects a short-lived OIDC token into the pod's filesystem.
#   3. When ESO calls AWS APIs, the AWS SDK exchanges that token for temporary
#      credentials by calling sts:AssumeRoleWithWebIdentity.
#   4. AWS validates the token against the EKS OIDC provider and checks the
#      sub condition (must match the ESO service account exactly).
#   5. Only the ESO service account in the ESO namespace can assume this role —
#      no other pod can, even if it somehow gets the role ARN.
resource "aws_iam_role" "eso" {
  name = "guestbook-${var.env_name}-eso"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${var.eso_namespace}:external-secrets"
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

# ESO only needs to read secrets — no write, no list, no delete.
# Resource is a list of ARNs, one per prefix in resolved_eso_prefixes.
# For the dev cluster (hosting dev + staging), this expands to two ARNs:
#   guestbook/dev/* and guestbook/staging/*
# For prod, it stays as a single ARN: guestbook/prod/*
# The wildcard suffix (*) is required because Secrets Manager appends a
# random 6-character suffix to every secret ARN for uniqueness.
resource "aws_iam_role_policy" "eso_secrets" {
  name = "eso-secrets-manager"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = [
        for prefix in local.resolved_eso_prefixes :
        "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${prefix}/*"
      ]
    }]
  })
}

# Install the External Secrets Operator from the official Helm chart.
# ESO registers the ExternalSecret and ClusterSecretStore CRDs. Without it,
# kubectl (and ArgoCD) will reject any manifest that uses those types.
#
# installCRDs = true: the chart ships the CRD manifests — we let it manage them
# rather than applying them separately, so upgrades stay in sync.
#
# The service account annotation is how IRSA works: the EKS token webhook sees
# the annotation and injects the AWS_ROLE_ARN env var so the SDK can call STS.
resource "helm_release" "eso" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = var.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
        }
      }
    })
  ]
}

# Create the ClusterSecretStore named "aws-secrets-manager".
# This name must match externalSecret.secretStoreName in charts/guestbook/values.yaml.
#
# ClusterSecretStore vs SecretStore:
#   SecretStore is namespace-scoped — only ExternalSecrets in the same namespace
#   can use it. ClusterSecretStore is cluster-scoped — any namespace can use it.
#   One ClusterSecretStore serves both the dev and prod namespaces without
#   duplicating the AWS auth config.
#
# The auth.jwt block tells ESO to use the external-secrets service account's
# IRSA token when calling Secrets Manager — no static AWS credentials anywhere.
#
# We use a null_resource + local-exec (same pattern as the finalizer stripper)
# instead of kubernetes_manifest because kubernetes_manifest tries to validate
# the CRD schema at plan time — before ESO has installed the CRD. local-exec
# runs only at apply time, after ESO is up and the CRD exists.
resource "null_resource" "cluster_secret_store" {
  depends_on = [helm_release.eso]

  triggers = {
    cluster_name  = var.cluster_name
    region        = var.region
    eso_role_arn  = aws_iam_role.eso.arn
    eso_namespace = var.eso_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --kubeconfig /tmp/kubeconfig-${var.cluster_name}

      KUBECONFIG=/tmp/kubeconfig-${var.cluster_name} kubectl apply -f - <<'YAML'
      apiVersion: external-secrets.io/v1beta1
      kind: ClusterSecretStore
      metadata:
        name: aws-secrets-manager
      spec:
        provider:
          aws:
            service: SecretsManager
            region: ${var.region}
            auth:
              jwt:
                serviceAccountRef:
                  name: external-secrets
                  namespace: ${var.eso_namespace}
      YAML

      rm -f /tmp/kubeconfig-${var.cluster_name}
    EOT
  }
}

# ---------------------------------------------------------------------------
# GitHub OAuth credentials for ArgoCD SSO — synced via ESO
# ---------------------------------------------------------------------------
# Prod-only (enable_sso defaults to false).
#
# The actual client ID/secret are NOT created here. A GitHub OAuth App has to
# be created manually (github.com -> Settings -> Developer settings -> OAuth
# Apps) and its credentials stored in Secrets Manager by hand, at the path
# below, as JSON: {"client_id": "...", "client_secret": "..."}. Terraform
# never generates or holds the actual secret value — only the *reference* to
# where ESO should find it. This is the same "Terraform never touches secret
# values" rule as every other ExternalSecret in this project.
locals {
  github_oauth_secret_name = "guestbook/${var.env_name}/argocd-github-oauth"
}

# ArgoCD's Dex config (wired up in the values block above) reads these
# credentials via $dex.github.clientID / $dex.github.clientSecret — a
# placeholder syntax argocd-server resolves by looking up matching keys in
# the argocd-secret Kubernetes Secret. That Secret already exists (the
# argo-cd Helm chart creates and owns it), so this ExternalSecret uses
# creationPolicy: Merge to add just these two keys into it, rather than
# creating a competing Secret object that Dex would never actually read.
resource "null_resource" "argocd_github_oauth_secret" {
  count = var.enable_sso ? 1 : 0

  depends_on = [null_resource.cluster_secret_store, helm_release.argocd]

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
    secret_name  = local.github_oauth_secret_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --kubeconfig /tmp/kubeconfig-${var.cluster_name}

      KUBECONFIG=/tmp/kubeconfig-${var.cluster_name} kubectl apply -f - <<'YAML'
      apiVersion: external-secrets.io/v1beta1
      kind: ExternalSecret
      metadata:
        name: argocd-github-oauth
        namespace: ${var.argocd_namespace}
      spec:
        secretStoreRef:
          name: aws-secrets-manager
          kind: ClusterSecretStore
        target:
          name: argocd-secret
          creationPolicy: Merge
        data:
          - secretKey: dex.github.clientID
            remoteRef:
              key: ${local.github_oauth_secret_name}
              property: client_id
          - secretKey: dex.github.clientSecret
            remoteRef:
              key: ${local.github_oauth_secret_name}
              property: client_secret
      YAML

      rm -f /tmp/kubeconfig-${var.cluster_name}
    EOT
  }
}

# ---------------------------------------------------------------------------
# ArgoCD finalizer cleanup (runs on destroy, before ArgoCD is uninstalled)
# ---------------------------------------------------------------------------

# Strip ArgoCD Application finalizers before the Helm releases are deleted.
#
# The problem: ArgoCD adds a finalizer to every Application CR. When you run
# `helm uninstall argocd`, Helm deletes the ArgoCD controller first. The
# Application CRs are then stuck in Terminating because they need the controller
# to process the finalizer — but the controller is gone. The cluster hangs.
#
# The fix: this null_resource runs a destroy provisioner BEFORE the Helm
# releases are deleted. It patches all Application CRs to remove the finalizer,
# so they delete instantly when Helm uninstalls ArgoCD.
#
# Dependency order during destroy (reverse of creation):
#   1. null_resource (provisioner strips finalizers)
#   2. helm_release.argocd_apps (Application CRs delete cleanly)
#   3. helm_release.argocd (ArgoCD uninstalls without hanging)
resource "null_resource" "strip_argocd_finalizers" {
  depends_on = [helm_release.argocd, helm_release.argocd_apps]

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --kubeconfig /tmp/kubeconfig-${self.triggers.cluster_name}
      for app in $(KUBECONFIG=/tmp/kubeconfig-${self.triggers.cluster_name} \
          kubectl get applications -n argocd -o name 2>/dev/null); do
        KUBECONFIG=/tmp/kubeconfig-${self.triggers.cluster_name} \
          kubectl patch "$app" -n argocd --type json \
          -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
      done
      rm -f /tmp/kubeconfig-${self.triggers.cluster_name}
    EOT
  }
}
