variable "account_id" {
  description = "AWS account ID for the staging environment."
  type        = string
}

variable "region" {
  description = "AWS region where all resources are deployed."
  type        = string
  default     = "eu-west-1"
}

variable "env" {
  description = "Environment name."
  type        = string
  default     = "staging"
}

variable "team" {
  description = "Owning team."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre code for billing allocation."
  type        = string
}

variable "ticket" {
  description = "Issue tracker ticket reference for this change (e.g. PLAT-1234)."
  type        = string
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Primary CIDR block for the staging VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ."
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ."
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "availability_zones" {
  description = "Ordered list of AZs to use for subnets."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
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
  description = "Security group ID controlling access to the Aurora cluster."
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Aurora storage."
  type        = string
}
