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
# ALB Security Group
# ---------------------------------------------------------------------------

# Pre-create the ALB security group in Terraform so we know its ID before
# apply completes. We pass this SG ID to the ALB Ingress via annotation, which
# tells LBC to use this SG instead of creating a new one automatically.
# Knowing the SG ID at Terraform time lets us add the NodePort ingress rule
# to the node security group in the same apply — no chicken-and-egg problem.
resource "aws_security_group" "alb" {
  name        = "guestbook-${var.env_name}-alb"
  description = "Security group for the guestbook ALB — allows HTTP inbound from internet"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "guestbook-${var.env_name}-alb"
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound — ALB needs to reach node NodePorts"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow the ALB to reach NGINX on the Kubernetes NodePort range (30000-32767).
# Without this rule the ALB health checks fail: the ALB SG can send traffic
# to the nodes but the node SG drops it before it reaches NGINX.
resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  security_group_id            = var.node_security_group_id
  description                  = "Allow ALB to reach NGINX NodePort range on EKS nodes"
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller — IRSA
# ---------------------------------------------------------------------------

# LBC runs in kube-system and calls AWS APIs to create/update ALBs and NLBs.
# It authenticates via IRSA: the service account token is exchanged for
# temporary AWS credentials by sts:AssumeRoleWithWebIdentity.
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

# The LBC IAM policy is defined by AWS upstream. It grants the controller the
# minimum permissions to manage ALBs, NLBs, target groups, security groups,
# and listener rules on behalf of Kubernetes Ingress objects.
#
# Source: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
# We pin to the permissions required by LBC v2.8.x (chart 1.8.x).
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
            "aws:RequestTag/elbv2.k8s.aws/cluster"   = true
            "aws:ResourceTag/elbv2.k8s.aws/cluster"  = false
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

# LBC must know the cluster name and VPC ID so it can tag resources correctly
# and discover the right subnets. The serviceAccount annotation wires up IRSA.
#
# enableServiceMutatorWebhook = false: disables the webhook that rewrites
# Service objects. We do not use NLB-mode Services here (NGINX uses NodePort),
# so this webhook is unnecessary and can cause apply-time timeouts if the
# cert-manager dependency is missing.
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

      enableServiceMutatorWebhook = false
    })
  ]
}

# ---------------------------------------------------------------------------
# NGINX Ingress Controller — Helm release
# ---------------------------------------------------------------------------

# NGINX is the in-cluster router. It reads all Ingress objects with
# className: nginx and maintains an upstream map: hostname → backend service.
#
# service.type: NodePort means NGINX does NOT create a LoadBalancer/NLB.
# Instead, Kubernetes opens a static port (auto-assigned in 30000-32767) on
# every node. The ALB (created below via the Ingress annotation) targets
# those nodes on that port.
#
# externalTrafficPolicy: Local preserves the client source IP. With the
# default Cluster policy, kube-proxy NATs the source IP on every hop, making
# access logs useless. Local skips the extra hop when the ALB targets a node
# that already runs an NGINX pod (which target-type: instance ensures).
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
          type = "NodePort"
          # Let Kubernetes auto-assign the NodePort — LBC discovers it
          # dynamically from the Service spec when building the target group.
          externalTrafficPolicy = "Local"
        }

        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = true
        }

        # Metrics endpoint for Prometheus scraping (Week 5 observability stack).
        metrics = {
          enabled = true
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# ALB Ingress — bridges the AWS ALB to the NGINX NodePort service
# ---------------------------------------------------------------------------

# This Ingress is the only resource with className: alb. AWS LBC sees it and:
#   1. Creates an internet-facing ALB in the public subnets
#   2. Creates a target group pointing at the NGINX NodePort on each node
#   3. Creates an HTTP:80 listener that forwards all traffic to that target group
#
# The security-groups annotation uses the pre-created ALB SG from above.
# This avoids the race where LBC creates a new SG that we haven't yet added
# to the node ingress rules.
#
# subnet annotations: required when subnets are not tagged with
#   kubernetes.io/role/elb = 1 (our VPC module doesn't set those tags).
#
# We use local-exec instead of kubernetes_manifest for the same reason as
# ClusterSecretStore: no CRD schema at plan time. An Ingress IS a core API
# object, but the IngressClass "alb" CRD (IngressClassParams) is registered
# by LBC and doesn't exist until LBC is up. local-exec runs at apply time,
# after LBC has installed its CRDs.
resource "null_resource" "alb_ingress" {
  depends_on = [helm_release.nginx, helm_release.lbc]

  triggers = {
    cluster_name     = var.cluster_name
    region           = var.region
    alb_sg_id        = aws_security_group.alb.id
    subnet_ids       = join(",", var.public_subnet_ids)
    nginx_namespace  = var.nginx_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --kubeconfig /tmp/kubeconfig-${var.cluster_name}

      KUBECONFIG=/tmp/kubeconfig-${var.cluster_name} kubectl apply -f - <<'YAML'
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: nginx-alb
        namespace: ${var.nginx_namespace}
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: instance
          alb.ingress.kubernetes.io/security-groups: ${aws_security_group.alb.id}
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
          alb.ingress.kubernetes.io/subnets: ${join(",", var.public_subnet_ids)}
          alb.ingress.kubernetes.io/healthcheck-path: /healthz
          alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
          alb.ingress.kubernetes.io/healthy-threshold-count: "2"
          alb.ingress.kubernetes.io/tags: Project=guestbook,Environment=${var.env_name},ManagedBy=terragrunt
      spec:
        ingressClassName: alb
        rules:
          - http:
              paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: ingress-nginx-controller
                      port:
                        number: 80
      YAML

      rm -f /tmp/kubeconfig-${var.cluster_name}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --kubeconfig /tmp/kubeconfig-${self.triggers.cluster_name}

      KUBECONFIG=/tmp/kubeconfig-${self.triggers.cluster_name} \
        kubectl delete ingress nginx-alb -n ${self.triggers.nginx_namespace} --ignore-not-found

      rm -f /tmp/kubeconfig-${self.triggers.cluster_name}
    EOT
  }
}
