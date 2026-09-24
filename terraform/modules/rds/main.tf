locals {
  tags = merge(var.common_tags, {
    service    = "rds"
    managed-by = "terraform"
  })
}

# ---------------------------------------------------------------------------
# Enhanced Monitoring IAM Role (CKV_AWS_118)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${var.cluster_identifier}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = "${var.cluster_identifier}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for Aurora cluster ${var.cluster_identifier}."

  tags = merge(local.tags, {
    Name = "${var.cluster_identifier}-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Aurora PostgreSQL Cluster
# ---------------------------------------------------------------------------
resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username

  # Secrets Manager manages the master password; no plaintext in state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final-snapshot"

  deletion_protection = var.deletion_protection
  apply_immediately   = var.apply_immediately

  # CKV_AWS_313: copy all resource tags to automated and manual snapshots
  copy_tags_to_snapshot = true

  # CKV_AWS_162: allow IAM users/roles to authenticate to the cluster
  iam_database_authentication_enabled = true

  # CKV_AWS_324: ship PostgreSQL and upgrade logs to CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Cluster Instances
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  # Instance 0 is the writer; subsequent instances are readers.
  promotion_tier = count.index

  apply_immediately            = var.apply_immediately
  preferred_maintenance_window = var.preferred_maintenance_window

  # CKV_AWS_226: apply minor engine version upgrades automatically
  auto_minor_version_upgrade = true

  # CKV_AWS_118: enhanced monitoring — 60s granularity
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # CKV_AWS_353: Performance Insights encrypted with the cluster KMS key
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period

  tags = merge(local.tags, {
    Name = "${var.cluster_identifier}-${count.index}"
    role = count.index == 0 ? "writer" : "reader"
  })
}
