output "role_arn" {
  description = "ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "ID of the IAM role."
  value       = aws_iam_role.this.id
}

output "role_unique_id" {
  description = "Unique ID assigned by AWS (stable across role deletion and re-creation, useful for policy conditions)."
  value       = aws_iam_role.this.unique_id
}
