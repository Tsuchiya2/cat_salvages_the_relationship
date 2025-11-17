# frozen_string_literal: true

# Helper module for Prometheus metrics collection
#
# Provides convenient methods for tracking application metrics
# throughout the LINE Bot application.
#
# @example
#   PrometheusMetrics.track_webhook_request('success')
#   PrometheusMetrics.track_event_success(event)
module PrometheusMetrics
  class << self
    # Track webhook processing duration
    #
    # @param event_type [String] Type of event processed
    # @param duration [Float] Duration in seconds
    def track_webhook_duration(event_type, duration)
      return unless defined?(WEBHOOK_DURATION)

      WEBHOOK_DURATION.observe({ event_type: event_type }, duration)
    end

    # Track webhook request
    #
    # @param status [String] Request status (success, error, timeout)
    def track_webhook_request(status)
      return unless defined?(WEBHOOK_REQUESTS_TOTAL)

      WEBHOOK_REQUESTS_TOTAL.increment(labels: { status: status })
    end

    # Track successful event processing
    #
    # @param event [Line::Bot::Event] LINE event
    def track_event_success(event)
      return unless defined?(EVENT_PROCESSED_TOTAL)

      EVENT_PROCESSED_TOTAL.increment(
        labels: { event_type: event.class.name, status: 'success' }
      )
    end

    # Track failed event processing
    #
    # @param event [Line::Bot::Event] LINE event
    # @param _exception [Exception] Error that occurred
    def track_event_failure(event, _exception)
      return unless defined?(EVENT_PROCESSED_TOTAL)

      EVENT_PROCESSED_TOTAL.increment(
        labels: { event_type: event.class.name, status: 'error' }
      )
    end

    # Track LINE API call
    #
    # @param method [String] API method name
    # @param status [String] HTTP status code
    # @param duration [Float] Duration in seconds
    def track_line_api_call(method, status, duration)
      return unless defined?(LINE_API_CALLS_TOTAL) && defined?(LINE_API_DURATION)

      LINE_API_CALLS_TOTAL.increment(labels: { method: method, status: status })
      LINE_API_DURATION.observe({ method: method }, duration)
    end

    # Track message send result
    #
    # @param status [String] Send status (success, error)
    def track_message_send(status)
      return unless defined?(MESSAGE_SEND_TOTAL)

      MESSAGE_SEND_TOTAL.increment(labels: { status: status })
    end

    # Update LINE groups count gauge
    #
    # @param count [Integer] Current number of LINE groups
    def update_group_count(count)
      return unless defined?(LINE_GROUPS_TOTAL)

      LINE_GROUPS_TOTAL.set({}, count)
    end
  end
end
