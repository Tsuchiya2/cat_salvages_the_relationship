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

# Database connection pool metrics
DATABASE_POOL_SIZE = prometheus.gauge(
  :database_pool_size,
  docstring: 'Database connection pool size (total connections)'
)

DATABASE_POOL_AVAILABLE = prometheus.gauge(
  :database_pool_available,
  docstring: 'Database connection pool available connections'
)

DATABASE_POOL_WAITING = prometheus.gauge(
  :database_pool_waiting,
  docstring: 'Number of threads waiting for database connections'
)

# Database query performance metrics
DATABASE_QUERY_DURATION = prometheus.histogram(
  :database_query_duration_seconds,
  docstring: 'Database query duration in seconds',
  labels: [:operation],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

# Migration progress metrics
MIGRATION_PROGRESS_PERCENT = prometheus.gauge(
  :migration_progress_percent,
  docstring: 'Migration progress percentage (0-100)'
)

MIGRATION_ERRORS_TOTAL = prometheus.counter(
  :migration_errors_total,
  docstring: 'Total migration errors encountered',
  labels: [:error_type]
)
