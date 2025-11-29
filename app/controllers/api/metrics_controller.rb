# frozen_string_literal: true

module Api
  # MetricsController - Receives PWA metrics from service worker
  #
  # @api public
  # @example POST /api/metrics
  #   Request body:
  #   {
  #     "metrics": [
  #       { "name": "cache_hit", "value": 1, "unit": "count", "tags": {...}, "trace_id": "..." }
  #     ]
  #   }
  class MetricsController < ApplicationController
    skip_before_action :verify_authenticity_token

    # Maximum metrics per request to prevent abuse
    MAX_METRICS_PER_REQUEST = 100

    # POST /api/metrics
    # Accepts array of metric entries and batch inserts them
    def create
      metrics_params = params.permit(metrics: [:name, :value, :unit, :trace_id, { tags: {} }])
      metrics = metrics_params[:metrics]

      return render_validation_error('No metrics provided') if metrics.blank?
      return render_validation_error("Maximum #{MAX_METRICS_PER_REQUEST} metrics per request") if metrics.size > MAX_METRICS_PER_REQUEST

      metric_entries = build_metric_entries(metrics)

      # Validate all entries before insert
      invalid_entries = metric_entries.reject { |entry| valid_metric_entry?(entry) }
      return render_validation_error('Invalid metric entries', invalid_entries.size) if invalid_entries.any?

      # Batch insert for performance
      # Note: insert_all is intentionally used here for performance with PWA metrics
      Metric.insert_all(metric_entries) # rubocop:disable Rails/SkipsModelValidations

      render json: { success: true, count: metric_entries.size }, status: :created
    rescue StandardError => e
      Rails.logger.error("MetricsController error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end

    private

    # Build metric entries from request params
    # @param metrics [Array<ActionController::Parameters>] Metrics from request
    # @return [Array<Hash>] Metric entries ready for insert
    def build_metric_entries(metrics)
      metrics.map do |metric|
        {
          name: metric[:name],
          value: metric[:value].to_d,
          unit: metric[:unit],
          tags: metric[:tags],
          trace_id: metric[:trace_id],
          created_at: Time.current
        }
      end
    end

    # Validate a single metric entry
    # @param entry [Hash] Metric entry to validate
    # @return [Boolean] True if valid
    def valid_metric_entry?(entry)
      return false if entry[:name].blank?
      return false if entry[:value].nil?

      true
    end

    # Render validation error response
    # @param message [String] Error message
    # @param details [Object] Optional error details
    def render_validation_error(message, details = nil)
      error_payload = { error: message }
      error_payload[:details] = details if details
      render json: error_payload, status: :unprocessable_entity
    end
  end
end
