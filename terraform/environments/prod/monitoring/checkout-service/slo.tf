resource "newrelic_service_level" "checkout_availability" {
  guid        = var.checkout_service_guid
  name        = "checkout-service availability"
  description = "28-day availability SLO — 99.9% success rate."

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = "Transaction"
      where = "appName = 'checkout-service-prod'"
    }
    bad_events {
      from  = "Transaction"
      where = "appName = 'checkout-service-prod' AND error IS true"
    }
  }

  objective {
    target = 99.9
    time_window {
      rolling {
        count = 28
        unit  = "DAY"
      }
    }
  }
}

resource "newrelic_service_level" "checkout_latency" {
  guid        = var.checkout_service_guid
  name        = "checkout-service latency p95"
  description = "28-day latency SLO — p95 < 500ms."

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = "Transaction"
      where = "appName = 'checkout-service-prod'"
    }
    bad_events {
      from  = "Transaction"
      where = "appName = 'checkout-service-prod' AND duration > 0.5"
    }
  }

  objective {
    target = 99.5
    time_window {
      rolling {
        count = 28
        unit  = "DAY"
      }
    }
  }
}

variable "checkout_service_guid" {
  description = "New Relic entity GUID for the checkout-service APM application."
  type        = string
}

variable "newrelic_account_id" {
  description = "New Relic account ID."
  type        = number
}
