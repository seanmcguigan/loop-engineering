# ---------------------------------------------------------------------------
# Dev environment — terraform.tfvars
# Replace placeholder values before first apply.
# ---------------------------------------------------------------------------

account_id  = "998877665544"
region      = "eu-west-1"
env         = "dev"
team        = "platform"
cost_centre = "CC-1042"
ticket      = "PLAT-0001"

# VPC — single AZ to minimise cost in dev
vpc_cidr             = "10.2.0.0/16"
public_subnet_cidrs  = ["10.2.0.0/24"]
private_subnet_cidrs = ["10.2.10.0/24"]
availability_zones   = ["eu-west-1a"]

# EKS
kubernetes_version = "1.30"
