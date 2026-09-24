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
  description = "Name of the EKS cluster Karpenter manages."
  type        = string
}

variable "cluster_endpoint" {
  description = "HTTPS API endpoint of the EKS cluster."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC Identity Provider (used for IRSA on the controller role)."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider without the https:// prefix (e.g. oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE)."
  type        = string
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where Karpenter is deployed."
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account" {
  description = "Kubernetes service account name used by the Karpenter controller pod."
  type        = string
  default     = "karpenter"
}

variable "node_iam_role_name" {
  description = "Name for the IAM role attached to EC2 instances launched by Karpenter."
  type        = string
}

variable "interruption_queue_arn" {
  description = "ARN of the SQS queue for EC2 Spot interruption and rebalance notifications. Leave empty to skip the SQS permission."
  type        = string
  default     = ""
}
