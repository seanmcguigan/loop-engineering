output "cluster_id" {
  description = "Identifier of the Aurora cluster."
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora cluster. Route all writes here."
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster. Route read-only traffic here."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Port on which the cluster accepts connections."
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_rds_cluster.this.database_name
}

output "master_username" {
  description = "Master username of the Aurora cluster."
  value       = aws_rds_cluster.this.master_username
  sensitive   = true
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master user password."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "cluster_resource_id" {
  description = "RDS cluster resource ID (used in IAM policy conditions for RDS IAM auth)."
  value       = aws_rds_cluster.this.cluster_resource_id
}
