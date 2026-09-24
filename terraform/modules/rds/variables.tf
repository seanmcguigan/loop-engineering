variable "common_tags" {
  description = "Common tags applied to all resources. Must include: env, team, cost-centre, ticket, managed-by. No default — caller must always provide this."
  type        = map(string)

  # Enforce required tag keys at plan time — not at apply, not at checkov.
  # Without this, a caller passing common_tags = {} produces untagged resources
  # that only fail policy checks later. This surfaces the error immediately.
  #
  # Logic (inside out):
  #   keys(var.common_tags)         → list of key names the caller provided
  #   for k in [...] : contains()   → one true/false per required key
  #   alltrue([...])                → true only if every required key is present
  #   condition = false             → Terraform rejects the plan with error_message
  validation {
    condition = alltrue([
      for k in ["env", "team", "cost-centre", "ticket", "managed-by"] :
      contains(keys(var.common_tags), k)
    ])
    error_message = "common_tags must include all required keys: env, team, cost-centre, ticket, managed-by."
  }
}

variable "cluster_identifier" {
  description = "Unique identifier for the Aurora cluster. Must be globally unique within the AWS account."
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "DB instance class for Aurora cluster instances."
  type        = string
  default     = "db.r7g.large"
}

variable "instance_count" {
  description = "Number of Aurora cluster instances. Minimum 2 for HA (writer + reader)."
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Name of the initial database created at cluster launch."
  type        = string
}

variable "master_username" {
  description = "Master username for the Aurora cluster."
  type        = string
  default     = "postgres"
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Use private subnets."
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs associated with the cluster."
  type        = list(string)
}

variable "kms_key_id" {
  description = "ARN of the KMS key used to encrypt Aurora storage and Performance Insights at rest."
  type        = string
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups. Must be between 1 and 35."
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range for automated backups (UTC). Format: hh24:mi-hh24:mi."
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range for maintenance events. Format: ddd:hh24:mi-ddd:hh24:mi."
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "skip_final_snapshot" {
  description = "Set to true only for non-production environments. Production must leave this false."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection on the cluster. Should be true for production."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately rather than during the next maintenance window."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Interval in seconds for Enhanced Monitoring metrics. Valid values: 0, 1, 5, 10, 15, 30, 60. Set to 0 to disable."
  type        = number
  default     = 60
}

variable "performance_insights_retention_period" {
  description = "Retention period for Performance Insights data in days. 7 is free; 731 requires additional cost."
  type        = number
  default     = 7
}
