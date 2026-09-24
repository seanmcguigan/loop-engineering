locals {
  tags = merge(var.common_tags, {
    service    = "iam-role"
    managed-by = "terraform"
  })
}

# ---------------------------------------------------------------------------
# IAM Role
# ---------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = var.assume_role_policy
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn != "" ? var.permissions_boundary_arn : null

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Managed Policy Attachments
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "this" {
  count = length(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}

# ---------------------------------------------------------------------------
# Inline Policy (optional)
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_name != "" ? 1 : 0

  name   = var.inline_policy_name
  role   = aws_iam_role.this.id
  policy = var.inline_policy_document
}
