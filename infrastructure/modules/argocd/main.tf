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
# Scoped to guestbook/{env}/* so a leak of this role cannot read
# secrets from any other project or environment in the same account.
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
      Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:guestbook/${var.env_name}/*"
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
  depends_on = [helm_release.argocd]

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
