# frozen_string_literal: true

# Metric - Stores PWA metrics from service worker
#
# @!attribute [rw] name
#   @return [String] Metric name (e.g., "cache_hit", "service_worker_registration")
# @!attribute [rw] value
#   @return [Decimal] Metric value
# @!attribute [rw] unit
#   @return [String] Unit of measurement (e.g., "count", "ms", "bytes")
# @!attribute [rw] tags
#   @return [Hash] Structured tags for filtering (e.g., {strategy: "cache-first"})
# @!attribute [rw] trace_id
#   @return [String] Distributed tracing ID for correlation
#
# Common metric names:
#   - service_worker_registration: SW registration count
#   - cache_hit: Cache hit count
#   - cache_miss: Cache miss count
#   - install_prompt_shown: Install prompt display count
#   - app_installed: App installation count
class Metric < ApplicationRecord
  validates :name, presence: true
  validates :value, presence: true, numericality: true

  scope :by_name, ->(name) { where(name: name) }
  scope :by_trace, ->(trace_id) { where(trace_id: trace_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Time.current.all_day) }

  # Aggregate metrics by name
  # @param name [String] Metric name
  # @return [Hash] Aggregated values (sum, count, avg, min, max)
  def self.aggregate(name)
    by_name(name).select(
      'SUM(value) as total',
      'COUNT(*) as count',
      'AVG(value) as average',
      'MIN(value) as minimum',
      'MAX(value) as maximum'
    ).take&.attributes&.symbolize_keys || {}
  end
end
