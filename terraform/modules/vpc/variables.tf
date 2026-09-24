variable "common_tags" {
  description = "Common tags applied to all resources. Must include: env, team, cost-centre, ticket, managed-by. No default — caller must always provide this."
  type        = map(string)

  validation {
    condition = alltrue([
      for k in ["env", "team", "cost-centre", "ticket", "managed-by"] :
      contains(keys(var.common_tags), k)
    ])
    error_message = "common_tags must include all required keys: env, team, cost-centre, ticket, managed-by."
  }
}

variable "name" {
  description = "Name prefix used for all VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets — one entry per availability zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets — one entry per availability zone."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Ordered list of availability zones into which subnets are deployed. Must align with public_subnet_cidrs and private_subnet_cidrs."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "When true, a NAT Gateway is created in each public subnet to allow egress from private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, a single NAT Gateway is shared across all AZs (cost reduction for non-prod). Ignored when enable_nat_gateway = false."
  type        = bool
  default     = false
}
