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
# VPC — two AZs sufficient for staging
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  name                 = "${var.env}-platform"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
  single_nat_gateway   = true # Single NAT GW saves cost in staging.
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
# EKS Cluster — smaller node group for staging
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
  node_group_desired_size = 2
  node_group_min_size     = 1
  node_group_max_size     = 4
  node_instance_types     = ["m5.large"]
  common_tags             = local.common_tags
}

# ---------------------------------------------------------------------------
# Aurora PostgreSQL — single instance for staging
# ---------------------------------------------------------------------------
module "rds" {
  source = "../../../modules/rds"

  cluster_identifier     = "${var.env}-platform-postgres"
  database_name          = "platform"
  instance_class         = "db.t4g.medium"
  instance_count         = 1
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [var.rds_security_group_id]
  kms_key_id             = var.rds_kms_key_arn
  backup_retention_period = 3
  skip_final_snapshot    = true
  deletion_protection    = false
  apply_immediately      = true
  common_tags            = local.common_tags
}
