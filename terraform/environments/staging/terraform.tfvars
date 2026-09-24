# ---------------------------------------------------------------------------
# Staging environment — terraform.tfvars
# Replace placeholder values before first apply.
# ---------------------------------------------------------------------------

account_id  = "210987654321"
region      = "eu-west-1"
env         = "staging"
team        = "platform"
cost_centre = "CC-1042"
ticket      = "PLAT-0001"

# VPC — two AZs to keep costs down
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["eu-west-1a", "eu-west-1b"]

# EKS
kubernetes_version = "1.30"

# RDS — replace with real resource IDs before apply
rds_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
rds_kms_key_arn       = "arn:aws:kms:eu-west-1:210987654321:key/bbbbcccc-dddd-eeee-ffff-aaaa00002222"
