locals {
  tags = merge(var.common_tags, {
    service    = "eks"
    managed-by = "terraform"
  })
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = local.tags
}

# ---------------------------------------------------------------------------
# OIDC Identity Provider (required for IRSA — Karpenter, FluxCD, etc.)
# ---------------------------------------------------------------------------
resource "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-oidc"
  })
}

# ---------------------------------------------------------------------------
# Default Managed Node Group (bootstraps cluster; Karpenter handles scale)
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.tags

  # Desired size is managed externally by Karpenter / Cluster Autoscaler.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
