output "controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role. Annotate the Karpenter service account with this value."
  value       = aws_iam_role.karpenter_controller.arn
}

output "controller_role_name" {
  description = "Name of the Karpenter controller IAM role."
  value       = aws_iam_role.karpenter_controller.name
}

output "node_role_arn" {
  description = "ARN of the IAM role assumed by Karpenter-launched EC2 instances."
  value       = aws_iam_role.karpenter_node.arn
}

output "node_role_name" {
  description = "Name of the IAM role for Karpenter-launched nodes."
  value       = aws_iam_role.karpenter_node.name
}

output "node_instance_profile_arn" {
  description = "ARN of the EC2 instance profile attached to Karpenter-launched nodes."
  value       = aws_iam_instance_profile.karpenter_node.arn
}

output "node_instance_profile_name" {
  description = "Name of the EC2 instance profile attached to Karpenter-launched nodes."
  value       = aws_iam_instance_profile.karpenter_node.name
}
