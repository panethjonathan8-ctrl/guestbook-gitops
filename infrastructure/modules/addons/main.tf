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
  }
}

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
        Effect = "Allow"
        Action = ["ec2:CreateSecurityGroup"]
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
