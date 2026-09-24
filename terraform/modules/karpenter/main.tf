locals {
  tags = merge(var.common_tags, {
    service    = "karpenter"
    managed-by = "terraform"
  })
}

# ---------------------------------------------------------------------------
# Karpenter Controller IAM Role (IRSA)
# Note: data.aws_iam_policy_document is a local in-memory data source and
# does not reach outside this module's state — compliant with module rules.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "karpenter_controller_assume" {
  statement {
    sid     = "KarpenterControllerIRSA"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.karpenter_namespace}:${var.karpenter_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "karpenter-controller-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume.json

  tags = merge(local.tags, {
    Name = "karpenter-controller-${var.cluster_name}"
  })
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "karpenter-controller-${var.cluster_name}"
  description = "Permissions required by the Karpenter controller on cluster ${var.cluster_name}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "AllowEC2NodeProvisioning"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:CreateTags",
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowPassRoleToNodes"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid    = "AllowEKSClusterInspection"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:*:*:cluster/${var.cluster_name}"
      },
      {
        Sid    = "AllowInstanceProfileManagement"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
        ]
        Resource = "*"
      },
    ],
    var.interruption_queue_arn != "" ? [{
      Sid    = "AllowInterruptionQueue"
      Effect = "Allow"
      Action = [
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
      ]
      Resource = var.interruption_queue_arn
    }] : [])
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ---------------------------------------------------------------------------
# Karpenter Node IAM Role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "karpenter_node_assume" {
  statement {
    sid     = "KarpenterNodeAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_node" {
  name               = var.node_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume.json

  tags = merge(local.tags, {
    Name = var.node_iam_role_name
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = var.node_iam_role_name
  role = aws_iam_role.karpenter_node.name

  tags = local.tags
}
