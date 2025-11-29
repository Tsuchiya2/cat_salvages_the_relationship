# frozen_string_literal: true

require 'prometheus/client'

prometheus = Prometheus::Client.registry

# Webhook metrics
WEBHOOK_DURATION = prometheus.histogram(
  :webhook_duration_seconds,
  docstring: 'Webhook processing duration in seconds',
  labels: [:event_type],
  buckets: [0.1, 0.5, 1, 2, 3, 5, 8, 10]
)

WEBHOOK_REQUESTS_TOTAL = prometheus.counter(
  :webhook_requests_total,
  docstring: 'Total webhook requests received',
  labels: [:status]
)

EVENT_PROCESSED_TOTAL = prometheus.counter(
  :event_processed_total,
  docstring: 'Total events processed',
  labels: %i[event_type status]
)

LINE_API_CALLS_TOTAL = prometheus.counter(
  :line_api_calls_total,
  docstring: 'Total LINE API calls',
  labels: %i[method status]
)

LINE_API_DURATION = prometheus.histogram(
  :line_api_duration_seconds,
  docstring: 'LINE API call duration',
  labels: [:method],
  buckets: [0.1, 0.5, 1, 2, 5]
)

LINE_GROUPS_TOTAL = prometheus.gauge(
  :line_groups_total,
  docstring: 'Total number of LINE groups'
)

MESSAGE_SEND_TOTAL = prometheus.counter(
  :message_send_total,
  docstring: 'Total messages sent',
  labels: [:status]
)

# Authentication metrics
AUTH_ATTEMPTS_TOTAL = prometheus.counter(
  :auth_attempts_total,
  docstring: 'Total authentication attempts',
  labels: %i[provider result]
)

AUTH_DURATION = prometheus.histogram(
  :auth_duration_seconds,
  docstring: 'Authentication request duration in seconds',
  labels: [:provider],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
)

AUTH_FAILURES_TOTAL = prometheus.counter(
  :auth_failures_total,
  docstring: 'Total authentication failures',
  labels: %i[provider reason]
)

AUTH_LOCKED_ACCOUNTS_TOTAL = prometheus.counter(
  :auth_locked_accounts_total,
  docstring: 'Total accounts locked due to brute force protection',
  labels: [:provider]
)

AUTH_ACTIVE_SESSIONS = prometheus.gauge(
  :auth_active_sessions,
  docstring: 'Number of currently active user sessions'
)
