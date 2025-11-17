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
  labels: [:event_type, :status]
)

LINE_API_CALLS_TOTAL = prometheus.counter(
  :line_api_calls_total,
  docstring: 'Total LINE API calls',
  labels: [:method, :status]
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
