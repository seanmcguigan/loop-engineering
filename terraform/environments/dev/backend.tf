terraform {
  backend "s3" {
    # Bucket follows the pattern: platform-tfstate-<account-id>-<region>
    bucket = "platform-tfstate-998877665544-eu-west-1"
    key    = "dev/platform/terraform.tfstate"
    region = "eu-west-1"

    # Encryption at rest — KMS key required by policy.
    encrypt    = true
    kms_key_id = "arn:aws:kms:eu-west-1:998877665544:key/ccccdddd-eeee-ffff-aaaa-bbbb00003333"

    # Native S3 state locking (Terraform 1.10+). No DynamoDB table required.
    use_lockfile = true
  }
}
