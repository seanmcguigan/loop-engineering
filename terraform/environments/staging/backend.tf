terraform {
  backend "s3" {
    # Bucket follows the pattern: platform-tfstate-<account-id>-<region>
    bucket = "platform-tfstate-210987654321-eu-west-1"
    key    = "staging/platform/terraform.tfstate"
    region = "eu-west-1"

    # Encryption at rest — KMS key required by policy.
    encrypt    = true
    kms_key_id = "arn:aws:kms:eu-west-1:210987654321:key/bbbbcccc-dddd-eeee-ffff-aaaa00002222"

    # Native S3 state locking (Terraform 1.10+). No DynamoDB table required.
    use_lockfile = true
  }
}
