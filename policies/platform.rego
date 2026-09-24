# ---------------------------------------------------------------------------
# OPA Policy: platform.rego
# Package:    data.platform
#
# Evaluates a Terraform plan JSON (terraform show -json plan.tfplan) and
# produces a set of deny messages for any planned resource that is missing
# one or more of the mandatory tags defined by the platform tagging schema.
#
# Required tags: env, team, service, cost-centre, ticket, managed-by
#
# Usage:
#   terraform plan -out=plan.tfplan
#   terraform show -json plan.tfplan > plan.json
#   opa eval -d ../../policies/ -i plan.json "data.platform.deny"
#
# A non-empty deny set must block the apply in CI.
# ---------------------------------------------------------------------------

package platform

import rego.v1

# ---------------------------------------------------------------------------
# Required tag keys — every planned resource must carry all of these.
# ---------------------------------------------------------------------------
required_tags := {
    "env",
    "team",
    "service",
    "cost-centre",
    "ticket",
    "managed-by",
}

# ---------------------------------------------------------------------------
# Resource types that are exempt from tag enforcement.
# IAM policy documents, data sources, and provider-level resources that
# cannot accept tags are listed here.
# ---------------------------------------------------------------------------
exempt_resource_types := {
    "aws_iam_policy_document",
    "aws_iam_role_policy",
    "aws_iam_role_policy_attachment",
    "aws_db_subnet_group",
    "aws_route_table_association",
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# planned_resources returns all resources that will be created or updated.
planned_resources[resource] if {
    resource := input.resource_changes[_]
    actions := resource.change.actions
    some action in actions
    action in {"create", "update"}
    not resource.type in exempt_resource_types
}

# effective_tags returns the merged tag map for a resource, preferring
# after-apply values and falling back to before values.
effective_tags(resource) := tags if {
    tags := resource.change.after.tags
} else := tags if {
    tags := resource.change.after_unknown
    # after_unknown means value is computed — treat as empty for enforcement.
    tags := {}
}

# missing_tags returns the set of required tag keys absent from a resource.
missing_tags(resource) := missing if {
    tags := effective_tags(resource)
    present := {k | tags[k]}
    missing := required_tags - present
}

# ---------------------------------------------------------------------------
# Deny rules
# ---------------------------------------------------------------------------

# deny: resource is missing one or more required tags.
deny contains msg if {
    resource := planned_resources[_]
    absent := missing_tags(resource)
    count(absent) > 0
    msg := sprintf(
        "Resource '%s' (type: %s) is missing required tags: %v. All resources must carry: env, team, service, cost-centre, ticket, managed-by.",
        [resource.address, resource.type, absent],
    )
}

# deny: a tag is present but its value is an empty string.
deny contains msg if {
    resource := planned_resources[_]
    tags := effective_tags(resource)
    key := required_tags[_]
    tags[key] == ""
    msg := sprintf(
        "Resource '%s' (type: %s) has an empty value for required tag '%s'. Tag values must be non-empty strings.",
        [resource.address, resource.type, key],
    )
}

# deny: managed-by must always be "terraform" for resources managed by this repo.
deny contains msg if {
    resource := planned_resources[_]
    tags := effective_tags(resource)
    tags["managed-by"] != "terraform"
    msg := sprintf(
        "Resource '%s' (type: %s) has managed-by='%s'; value must be 'terraform' for all platform-managed resources.",
        [resource.address, resource.type, tags["managed-by"]],
    )
}

# deny: ticket tag must match the expected pattern (e.g. PLAT-1234).
deny contains msg if {
    resource := planned_resources[_]
    tags := effective_tags(resource)
    ticket := tags["ticket"]
    not regex.match(`^[A-Z]+-[0-9]+$`, ticket)
    msg := sprintf(
        "Resource '%s' (type: %s) has ticket='%s'; value must match the pattern PROJECT-NUMBER (e.g. PLAT-1234).",
        [resource.address, resource.type, ticket],
    )
}

# ---------------------------------------------------------------------------
# allow: inverse of deny for use as a boolean check in CI scripts.
# ---------------------------------------------------------------------------
allow if {
    count(deny) == 0
}
