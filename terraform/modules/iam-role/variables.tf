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

variable "role_name" {
  description = "Name of the IAM role. Must be unique within the account."
  type        = string
}

variable "assume_role_policy" {
  description = "JSON-encoded assume-role policy document (trust policy). Determines which principals can assume this role."
  type        = string
}

variable "policy_arns" {
  description = "List of managed IAM policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policy_name" {
  description = "Name for an optional inline policy. Set to an empty string to skip inline policy creation."
  type        = string
  default     = ""
}

variable "inline_policy_document" {
  description = "JSON-encoded inline policy document. Only evaluated when inline_policy_name is non-empty."
  type        = string
  default     = ""
}

variable "permissions_boundary_arn" {
  description = "ARN of the permissions boundary policy to apply to the role. Set to an empty string to skip."
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for this role (between 3600 and 43200)."
  type        = number
  default     = 3600
}
