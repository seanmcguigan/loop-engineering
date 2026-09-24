locals {
  # common_tags is the single source of truth for mandatory tag values.
  # All modules merge this with resource-specific tags via local.tags inside each module.
  common_tags = {
    env         = var.env
    team        = var.team
    cost-centre = var.cost_centre
    ticket      = var.ticket
    managed-by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  name                 = "${var.env}-platform"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
  single_nat_gateway   = false # One NAT GW per AZ for prod HA.
  common_tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM Roles for EKS
# ---------------------------------------------------------------------------
module "eks_cluster_role" {
  source = "../../../modules/iam-role"

  role_name = "${var.env}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
  common_tags = local.common_tags
}

module "eks_node_role" {
  source = "../../../modules/iam-role"

  role_name = "${var.env}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
  common_tags = local.common_tags
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
module "eks" {
  source = "../../../modules/eks"

  cluster_name            = "${var.env}-platform"
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  cluster_role_arn        = module.eks_cluster_role.role_arn
  node_role_arn           = module.eks_node_role.role_arn
  endpoint_private_access = true
  endpoint_public_access  = false
  node_group_desired_size = 3
  node_group_min_size     = 3
  node_group_max_size     = 6
  node_instance_types     = ["m7i.xlarge"]
  common_tags             = local.common_tags
}

# ---------------------------------------------------------------------------
# Karpenter
# ---------------------------------------------------------------------------
module "karpenter" {
  source = "../../../modules/karpenter"

  cluster_name              = module.eks.cluster_name
  cluster_endpoint          = module.eks.cluster_endpoint
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  node_iam_role_name        = "${var.env}-karpenter-node"
  common_tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Aurora PostgreSQL (RDS)
# ---------------------------------------------------------------------------
module "rds" {
  source = "../../../modules/rds"

  cluster_identifier     = "${var.env}-platform-postgres"
  database_name          = "platform"
  instance_class         = var.rds_instance_class
  instance_count         = 2
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [var.rds_security_group_id]
  kms_key_id             = var.rds_kms_key_arn
  backup_retention_period = 14
  skip_final_snapshot    = false
  deletion_protection    = true
  common_tags            = local.common_tags
}
