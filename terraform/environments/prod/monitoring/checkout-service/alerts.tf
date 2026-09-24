resource "newrelic_alert_policy" "checkout" {
  name                = "checkout-service"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

resource "newrelic_nrql_alert_condition" "checkout_burn_rate_critical" {
  policy_id = newrelic_alert_policy.checkout.id
  name      = "checkout-service SLO burn rate critical (5x in 1h)"
  type      = "static"

  nrql {
    query = "SELECT rate(count(*), 1 hour) FROM Transaction WHERE appName = 'checkout-service-prod' AND error IS true"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 3600
    threshold_occurrences = "all"
  }
}

resource "newrelic_notification_destination" "pagerduty" {
  name = "checkout-pagerduty"
  type = "PAGERDUTY_ACCOUNT_INTEGRATION"

  property {
    key   = "two_way_integration"
    value = "true"
  }

  auth_token {
    prefix = "Token token="
    token  = var.pagerduty_service_key
  }
}

resource "newrelic_nrql_alert_condition" "checkout_burn_rate_warning" {
  policy_id = newrelic_alert_policy.checkout.id
  name      = "checkout-service SLO burn rate warning (2x in 6h)"
  type      = "static"

  nrql {
    query = "SELECT rate(count(*), 6 hour) FROM Transaction WHERE appName = 'checkout-service-prod' AND error IS true"
  }

  warning {
    operator              = "above"
    threshold             = 2
    threshold_duration    = 21600
    threshold_occurrences = "all"
  }
}

variable "pagerduty_service_key" {
  description = "PagerDuty service integration key — sourced from secrets manager, not hardcoded."
  type        = string
  sensitive   = true
}
