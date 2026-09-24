locals {
  common_tags = {
    env         = var.env
    team        = var.team
    cost-centre = var.cost_centre
    ticket      = var.ticket
    managed-by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# VPC — minimal single-AZ for dev to reduce cost
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  name                 = "${var.env}-platform"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
  single_nat_gateway   = true
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
# EKS Cluster — minimal footprint for dev
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
  node_group_desired_size = 1
  node_group_min_size     = 1
  node_group_max_size     = 3
  node_instance_types     = ["t3.medium"]
  common_tags             = local.common_tags
}

# Note: No RDS in dev by default. Use the rds module and add a
# rds_security_group_id / rds_kms_key_arn variable if a database is needed.
