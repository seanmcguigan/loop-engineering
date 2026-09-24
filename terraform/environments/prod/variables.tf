variable "account_id" {
  description = "AWS account ID for the production environment. Used in IAM ARNs and backend bucket names."
  type        = string
}

variable "region" {
  description = "AWS region where all resources are deployed."
  type        = string
  default     = "eu-west-1"
}

variable "env" {
  description = "Environment name. Used as a tag and in resource name prefixes."
  type        = string
  default     = "prod"
}

variable "team" {
  description = "Owning team. Used in cost allocation tags."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre code applied to all resources for billing allocation."
  type        = string
}

variable "ticket" {
  description = "Jira or issue tracker ticket reference that approved this change (e.g. PLAT-1234)."
  type        = string
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Primary CIDR block for the production VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Ordered list of AZs to use for subnets."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "EKS Kubernetes control plane version."
  type        = string
  default     = "1.30"
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------
variable "rds_security_group_id" {
  description = "ID of the security group that controls inbound access to the Aurora cluster."
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Aurora storage at rest."
  type        = string
}

variable "rds_instance_class" {
  description = "DB instance class for Aurora cluster instances."
  type        = string
  default     = "db.r6g.large"
}
