terraform {
  required_providers {
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

  values = [
    yamlencode({
      applications = [
        {
          name      = "app-of-apps"
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
      ]
    })
  ]
}

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
