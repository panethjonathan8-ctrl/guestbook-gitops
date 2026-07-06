# One-time migration map for issue #84: this module used to be sourced
# directly from the registry (terraform.source pointed straight at
# terraform-aws-modules/eks/aws in _envcommon/eks.hcl), so every resource
# lived at the top level of state. Wrapping it in module "this" nests every
# resource one level deeper. Without these moved blocks, Terraform would
# plan to destroy and recreate the entire cluster and node group (and
# everything downstream: every pod, ArgoCD, the ALB) instead of recognizing
# it as the same infrastructure.
# Generated from the real prod state (`terragrunt state list` against the
# only cluster that exists today) — do not hand-edit. Safe to leave in place
# permanently; a moved block is a no-op if its "from" address is not found
# in state (e.g. dev, which currently has no cluster applied).

moved {
  from = data.aws_caller_identity.current[0]
  to   = module.this.data.aws_caller_identity.current[0]
}

moved {
  from = data.aws_eks_addon_version.this["coredns"]
  to   = module.this.data.aws_eks_addon_version.this["coredns"]
}

moved {
  from = data.aws_eks_addon_version.this["kube-proxy"]
  to   = module.this.data.aws_eks_addon_version.this["kube-proxy"]
}

moved {
  from = data.aws_eks_addon_version.this["vpc-cni"]
  to   = module.this.data.aws_eks_addon_version.this["vpc-cni"]
}

moved {
  from = data.aws_iam_policy_document.assume_role_policy[0]
  to   = module.this.data.aws_iam_policy_document.assume_role_policy[0]
}

moved {
  from = data.aws_iam_session_context.current[0]
  to   = module.this.data.aws_iam_session_context.current[0]
}

moved {
  from = data.aws_partition.current[0]
  to   = module.this.data.aws_partition.current[0]
}

moved {
  from = data.tls_certificate.this[0]
  to   = module.this.data.tls_certificate.this[0]
}

moved {
  from = aws_ec2_tag.cluster_primary_security_group["Environment"]
  to   = module.this.aws_ec2_tag.cluster_primary_security_group["Environment"]
}

moved {
  from = aws_ec2_tag.cluster_primary_security_group["ManagedBy"]
  to   = module.this.aws_ec2_tag.cluster_primary_security_group["ManagedBy"]
}

moved {
  from = aws_ec2_tag.cluster_primary_security_group["Project"]
  to   = module.this.aws_ec2_tag.cluster_primary_security_group["Project"]
}

moved {
  from = aws_eks_access_entry.this["github_actions"]
  to   = module.this.aws_eks_access_entry.this["github_actions"]
}

moved {
  from = aws_eks_access_entry.this["guestbook_dev"]
  to   = module.this.aws_eks_access_entry.this["guestbook_dev"]
}

moved {
  from = aws_eks_access_policy_association.this["github_actions_admin"]
  to   = module.this.aws_eks_access_policy_association.this["github_actions_admin"]
}

moved {
  from = aws_eks_access_policy_association.this["guestbook_dev_admin"]
  to   = module.this.aws_eks_access_policy_association.this["guestbook_dev_admin"]
}

moved {
  from = aws_eks_addon.before_compute["vpc-cni"]
  to   = module.this.aws_eks_addon.before_compute["vpc-cni"]
}

moved {
  from = aws_eks_addon.this["coredns"]
  to   = module.this.aws_eks_addon.this["coredns"]
}

moved {
  from = aws_eks_addon.this["kube-proxy"]
  to   = module.this.aws_eks_addon.this["kube-proxy"]
}

moved {
  from = aws_eks_cluster.this[0]
  to   = module.this.aws_eks_cluster.this[0]
}

moved {
  from = aws_iam_openid_connect_provider.oidc_provider[0]
  to   = module.this.aws_iam_openid_connect_provider.oidc_provider[0]
}

moved {
  from = aws_iam_role.this[0]
  to   = module.this.aws_iam_role.this[0]
}

moved {
  from = aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]
  to   = module.this.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]
}

moved {
  from = aws_security_group.cluster[0]
  to   = module.this.aws_security_group.cluster[0]
}

moved {
  from = aws_security_group.node[0]
  to   = module.this.aws_security_group.node[0]
}

moved {
  from = aws_security_group_rule.cluster["ingress_nodes_443"]
  to   = module.this.aws_security_group_rule.cluster["ingress_nodes_443"]
}

moved {
  from = aws_security_group_rule.node["egress_all"]
  to   = module.this.aws_security_group_rule.node["egress_all"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_10251_webhook"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_10251_webhook"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_443"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_443"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_4443_webhook"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_4443_webhook"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_6443_webhook"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_6443_webhook"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_8443_webhook"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_8443_webhook"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_9443_webhook"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_9443_webhook"]
}

moved {
  from = aws_security_group_rule.node["ingress_cluster_kubelet"]
  to   = module.this.aws_security_group_rule.node["ingress_cluster_kubelet"]
}

moved {
  from = aws_security_group_rule.node["ingress_nodes_ephemeral"]
  to   = module.this.aws_security_group_rule.node["ingress_nodes_ephemeral"]
}

moved {
  from = aws_security_group_rule.node["ingress_self_coredns_tcp"]
  to   = module.this.aws_security_group_rule.node["ingress_self_coredns_tcp"]
}

moved {
  from = aws_security_group_rule.node["ingress_self_coredns_udp"]
  to   = module.this.aws_security_group_rule.node["ingress_self_coredns_udp"]
}

moved {
  from = time_sleep.this[0]
  to   = module.this.time_sleep.this[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].data.aws_iam_policy_document.assume_role_policy[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].data.aws_iam_policy_document.assume_role_policy[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].data.aws_ssm_parameter.ami[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].data.aws_ssm_parameter.ami[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].aws_eks_node_group.this[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_eks_node_group.this[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].aws_iam_role.this[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_iam_role.this[0]
}

# These three skip straight to the ARN-keyed address instead of the
# short-name-keyed one. The registry module ships its own internal `moved`
# block (in eks-managed-node-group/migrations.tf) renaming these same keys
# from short policy names to full ARNs — our real state still has the old
# short-name keys, so pointing our own move here at the intermediate
# (still-short-keyed) wrapped address collides with the module's own move
# and Terraform rejects it as an ambiguous chain. Landing directly on the
# module's true final address avoids the collision entirely.
moved {
  from = module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["AmazonEC2ContainerRegistryReadOnly"]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]
}

moved {
  from = module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["AmazonEKSWorkerNodePolicy"]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]
}

moved {
  from = module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["AmazonEKS_CNI_Policy"]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
}

moved {
  from = module.eks_managed_node_group["guestbook"].aws_launch_template.this[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].aws_launch_template.this[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].module.user_data.data.cloudinit_config.al2023_eks_managed_node_group[0]
  to   = module.this.module.eks_managed_node_group["guestbook"].module.user_data.data.cloudinit_config.al2023_eks_managed_node_group[0]
}

moved {
  from = module.eks_managed_node_group["guestbook"].module.user_data.null_resource.validate_cluster_service_cidr
  to   = module.this.module.eks_managed_node_group["guestbook"].module.user_data.null_resource.validate_cluster_service_cidr
}
