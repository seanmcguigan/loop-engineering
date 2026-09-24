# ---------------------------------------------------------------------------
# Production environment — terraform.tfvars
# Replace placeholder values before first apply.
# ---------------------------------------------------------------------------

account_id  = "123456789012"
region      = "eu-west-1"
env         = "prod"
team        = "platform"
cost_centre = "CC-1042"
ticket      = "PLAT-0001"

# VPC
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# EKS
kubernetes_version = "1.30"

# RDS — replace with real resource IDs before apply
rds_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
rds_kms_key_arn       = "arn:aws:kms:eu-west-1:123456789012:key/aaaabbbb-cccc-dddd-eeee-ffff00001111"
rds_instance_class    = "db.r6g.large"
