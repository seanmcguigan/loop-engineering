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

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role assumed by the EKS control plane."
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role assumed by worker nodes in the default managed node group."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which the cluster is deployed. Used for tagging."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used for the EKS control plane ENIs and default node group. Use private subnets."
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable the private Kubernetes API endpoint (recommended: true for production)."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public Kubernetes API endpoint."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint when endpoint_public_access = true."
  type        = list(string)
  default     = []
}

variable "cluster_log_types" {
  description = "List of EKS control plane log types to send to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the default managed node group."
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 10
}

variable "node_instance_types" {
  description = "EC2 instance types for the default managed node group. Karpenter manages additional capacity."
  type        = list(string)
  default     = ["m5.large"]
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) for worker nodes."
  type        = number
  default     = 50
}
