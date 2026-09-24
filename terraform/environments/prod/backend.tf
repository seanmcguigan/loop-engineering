terraform {
  backend "s3" {
    # Bucket follows the pattern: platform-tfstate-<account-id>-<region>
    bucket = "platform-tfstate-123456789012-eu-west-1"
    key    = "prod/platform/terraform.tfstate"
    region = "eu-west-1"

    # Encryption at rest — KMS key required by policy.
    encrypt    = true
    kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/aaaabbbb-cccc-dddd-eeee-ffff00001111"

    # Native S3 state locking (Terraform 1.10+). No DynamoDB table required.
    use_lockfile = true
  }
}
