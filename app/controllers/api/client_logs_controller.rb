# frozen_string_literal: true

module Api
  # ClientLogsController - Receives client-side logs from browser/service worker
  #
  # @api public
  # @example POST /api/client_logs
  #   Request body:
  #   {
  #     "logs": [
  #       { "level": "error", "message": "...", "context": {...}, "url": "...", "trace_id": "..." }
  #     ]
  #   }
  class ClientLogsController < ApplicationController
    skip_before_action :verify_authenticity_token

    # Maximum logs per request to prevent abuse
    MAX_LOGS_PER_REQUEST = 100

    # POST /api/client_logs
    # Accepts array of log entries and batch inserts them
    def create
      logs_params = params.permit(logs: [:level, :message, :url, :trace_id, { context: {} }])
      logs = logs_params[:logs]

      return render_error('No logs provided') if logs.blank?
      return render_error("Maximum #{MAX_LOGS_PER_REQUEST} logs per request") if logs.size > MAX_LOGS_PER_REQUEST

      log_entries = build_log_entries(logs)
      invalid_entries = log_entries.reject { |entry| valid_log_entry?(entry) }

      return render_invalid_entries(invalid_entries.size) if invalid_entries.any?

      # Batch insert for performance (skips validations intentionally for performance)
      ClientLog.insert_all(log_entries) # rubocop:disable Rails/SkipsModelValidations

      render json: { success: true, count: log_entries.size }, status: :created
    rescue StandardError => e
      Rails.logger.error("ClientLogsController error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end

    private

    # Build log entries with user_agent from request
    # @param logs [Array<Hash>] Array of log parameters
    # @return [Array<Hash>] Array of log entries ready for insertion
    def build_log_entries(logs)
      logs.map do |log|
        {
          level: log[:level],
          message: log[:message],
          context: log[:context],
          url: log[:url],
          trace_id: log[:trace_id],
          user_agent: request.user_agent,
          created_at: Time.current
        }
      end
    end

    # Validate a single log entry
    # @param entry [Hash] Log entry to validate
    # @return [Boolean] True if valid
    def valid_log_entry?(entry)
      return false if entry[:level].blank?
      return false if entry[:message].blank?
      return false unless ClientLog::VALID_LEVELS.include?(entry[:level])

      true
    end

    # Render error response
    # @param message [String] Error message
    def render_error(message)
      render json: { error: message }, status: :unprocessable_entity
    end

    # Render invalid entries response
    # @param count [Integer] Number of invalid entries
    def render_invalid_entries(count)
      render json: { error: 'Invalid log entries', details: count }, status: :unprocessable_entity
    end
  end
end
