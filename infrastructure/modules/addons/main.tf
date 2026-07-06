locals {
  oidc_provider_url = replace(
    var.oidc_provider_arn,
    "arn:aws:iam::${var.account_id}:oidc-provider/",
    ""
  )
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller — IRSA
# ---------------------------------------------------------------------------

# LBC calls AWS APIs (elasticloadbalancing, ec2, acm) to create and manage
# ALBs in response to Ingress objects with ingressClassName: alb.
# It authenticates via IRSA — same OIDC token-exchange as ESO.
resource "aws_iam_role" "lbc" {
  name = "guestbook-${var.env_name}-lbc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${var.lbc_namespace}:aws-load-balancer-controller"
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

# Full LBC IAM policy as defined by AWS upstream.
# Source: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
# Pinned to the permissions required by LBC chart 1.8.x / controller v2.8.x.
resource "aws_iam_role_policy" "lbc" {
  name = "lbc-policy"
  role = aws_iam_role.lbc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:GetSecurityGroupsForVpc",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeCapacityReservation",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:ListWebACLs",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null         = { "aws:RequestedRegion" = false }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = true
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = false
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = false }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
        Resource = "*"
        Condition = {
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = false }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = true
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = false
          }
        }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListenerAttributes",
          "elasticloadbalancing:ModifyCapacityReservation",
          "elasticloadbalancing:ModifyListener",
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = false }
        }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
        ]
        Condition = {
          StringEquals = {
            "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"]
          }
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = false }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule",
        ]
        Resource = "*"
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller — Helm release
# ---------------------------------------------------------------------------

resource "helm_release" "lbc" {
  depends_on = [aws_iam_role_policy.lbc]

  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.lbc_chart_version
  namespace        = var.lbc_namespace
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      clusterName = var.cluster_name
      vpcId       = var.vpc_id
      region      = var.region

      serviceAccount = {
        name = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
        }
      }

      # The service mutator webhook rewrites Service objects to use NLB.
      # We use ClusterIP for NGINX (ALB targets pod IPs via target-type: ip),
      # so this webhook adds no value and can cause timeout errors when
      # cert-manager is absent.
      enableServiceMutatorWebhook = false
    })
  ]
}

# ---------------------------------------------------------------------------
# NGINX Ingress Controller — Helm release
# ---------------------------------------------------------------------------

# NGINX is the in-cluster L7 router. It reads all Ingress objects with
# ingressClassName: nginx and routes requests by hostname to the correct
# backend service.
#
# service.type: ClusterIP — NGINX does not need a NodePort or LoadBalancer
# service. The ALB (created by LBC when it reads the cluster-ingress chart)
# uses target-type: ip, which means the ALB targets NGINX pod IPs directly
# via VPC routing. VPC CNI assigns a real VPC IP to every pod, so the ALB
# can reach pods without any NodePort translation hop.
#
# With target-type: ip, LBC automatically manages the security group rule
# that allows ALB → NGINX pods on port 80. No manual SG rules needed.
resource "helm_release" "nginx" {
  depends_on = [helm_release.lbc]

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.nginx_chart_version
  namespace        = var.nginx_namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      controller = {
        service = {
          type = "ClusterIP"
        }

        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = true
        }

        metrics = {
          enabled = true
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# EBS CSI driver — IRSA, EKS addon, default StorageClass
# ---------------------------------------------------------------------------
# Prod-only (enable_ebs_csi_driver defaults to false). Gives Prometheus and
# Loki real EBS-backed PersistentVolumeClaims instead of emptyDir, so their
# data survives a pod restart, not just a running cluster.

# CSI driver calls AWS APIs (ec2:CreateVolume, AttachVolume, DeleteVolume,
# etc.) to provision real disks in response to PVCs. IRSA — same pattern as
# the LBC role above: only the ebs-csi-controller-sa service account in
# kube-system can assume this role, no other pod on the cluster can.
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "guestbook-${var.env_name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
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

# AWS-managed policy scoped to exactly what the CSI driver needs (create,
# attach, detach, delete, describe volumes/snapshots) — no broader ec2:*.
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Resolves the latest addon version compatible with the cluster's Kubernetes
# version at apply time — same "most_recent" idea used for vpc-cni/coredns
# in _envcommon/eks.hcl, just done manually here since this is a standalone
# aws_eks_addon resource rather than going through the EKS module's addon block.
data "aws_eks_addon_version" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi[0].version
  service_account_role_arn    = aws_iam_role.ebs_csi[0].arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

# EKS does not ship a default StorageClass for CSI-based dynamic provisioning
# — without this, a PVC with storageClassName: gp3 would sit Pending forever
# with nothing to bind it. WaitForFirstConsumer delays volume creation until
# a pod actually claims it, so the volume gets created in the same
# Availability Zone as the node the pod is scheduled to (EBS volumes are
# zonal — creating it too early can pick the wrong AZ).
resource "kubernetes_storage_class_v1" "gp3" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  depends_on = [aws_eks_addon.ebs_csi]

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
  }
}

# ---------------------------------------------------------------------------
# external-dns — IRSA, Helm release
# ---------------------------------------------------------------------------
# Prod-only (enable_external_dns defaults to false). Watches Ingress objects
# in the cluster and keeps Route 53 in sync with whatever hostname the ALB
# actually has right now. This is what makes argocd.guestbookinterview.lol
# survive the ALB being destroyed and recreated with a new DNS name every
# time the cluster is torn down for cost savings — no hand-maintained record,
# no custom "watch the ALB" controller.

# IRSA — same pattern as the LBC and EBS CSI roles above. Only the
# external-dns service account can assume this role.
resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name = "guestbook-${var.env_name}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${var.external_dns_namespace}:external-dns"
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

# ChangeResourceRecordSets is scoped to exactly the one hosted zone ARN we
# pass in — external-dns cannot write to any other zone in the account, even
# though the role has valid AWS credentials.
#
# ListHostedZones / ListResourceRecordSets / ListTagsForResource use
# Resource = "*" because the Route 53 API does not support resource-level
# permissions on those read-only, account-wide list actions — there is no
# ARN to scope them to. This is the one place in this module where a
# wildcard resource is unavoidable rather than a shortcut; external-dns's own
# --domain-filter (set below) is what keeps it from acting on any zone other
# than ours despite having list visibility into all of them.
resource "aws_iam_role_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name = "external-dns-policy"
  role = aws_iam_role.external_dns[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = [var.dns_zone_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  depends_on = [aws_iam_role_policy.external_dns]

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_chart_version
  namespace        = var.external_dns_namespace
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      provider = "aws"
      aws = {
        region = var.region
      }

      # Restricts which zones external-dns will act on. IAM's ListHostedZones
      # already can't be scoped to one zone (see above) — this is the actual
      # enforcement point that keeps it from touching zones outside this
      # project even if one existed in the same account.
      domainFilters = [var.dns_domain_name]

      # sync creates AND deletes records to match current Ingress state. That
      # matters here specifically because clusters in this project get torn
      # down and rebuilt to save cost — sync means a removed Ingress (or a
      # torn-down cluster) cleans up its DNS record automatically instead of
      # leaving a stale entry pointing at a dead ALB.
      policy = "sync"

      # TXT registry: external-dns writes a TXT record next to each A record
      # recording that it, not a human or another tool, owns that record.
      # Without an owner ID, a second external-dns instance (or a future
      # dev-cluster one) could fight over the same zone. txtOwnerId scopes
      # ownership per-environment.
      txtOwnerId = "guestbook-${var.env_name}"

      # Restricts external-dns to only the ALB-class Ingress (nginx-alb in
      # charts/cluster-ingress) as a DNS source. Without this, external-dns
      # also reads every NGINX-class per-app Ingress (guestbook, argocd-server)
      # — and ingress-nginx reports its own ClusterIP as a placeholder
      # status.loadBalancer address on those, which isn't externally routable
      # at all. That produced a real bug: www.guestbookinterview.lol got an
      # A record pointing at an internal ClusterIP instead of the ALB. Only
      # the ALB Ingress has a real, externally-routable address, so it's the
      # only one that should ever be a DNS source.
      extraArgs = ["--ingress-class=alb"]

      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns[0].arn
        }
      }
    })
  ]
}
