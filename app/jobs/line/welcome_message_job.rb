# frozen_string_literal: true

# Sends welcome messages to LINE groups outside database transactions.
class Line::WelcomeMessageJob < ApplicationJob
  queue_as :default

  def perform(group_id, message)
    adapter = Line::ClientProvider.client
    response = adapter.push_message(group_id, message)
    PrometheusMetrics.track_message_send('success')
    response
  rescue StandardError => e
    Rails.logger.error("WelcomeMessageJob failed for #{group_id}: #{e.message}")
    PrometheusMetrics.track_message_send('error')
    raise
  end
end
