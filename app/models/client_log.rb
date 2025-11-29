# frozen_string_literal: true

# ClientLog - Stores client-side logs from browser/service worker
#
# @!attribute [rw] level
#   @return [String] Log level: "error", "warn", "info", "debug"
# @!attribute [rw] message
#   @return [String] Log message
# @!attribute [rw] context
#   @return [Hash] Structured log context data
# @!attribute [rw] user_agent
#   @return [String] Browser user agent string
# @!attribute [rw] url
#   @return [String] URL where log was generated
# @!attribute [rw] trace_id
#   @return [String] Distributed tracing ID for correlation
class ClientLog < ApplicationRecord
  VALID_LEVELS = %w[error warn info debug].freeze

  validates :level, presence: true, inclusion: { in: VALID_LEVELS }
  validates :message, presence: true

  scope :errors, -> { where(level: 'error') }
  scope :warnings, -> { where(level: 'warn') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_trace, ->(trace_id) { where(trace_id: trace_id) }
end
