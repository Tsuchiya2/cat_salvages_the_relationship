# frozen_string_literal: true

# Sends scheduled reminder messages to LINE groups.
class Line::ReminderJob < ApplicationJob
  queue_as :default

  def perform(group_id, messages)
    adapter = Line::ClientProvider.client
    retry_handler = Resilience::RetryHandler.new(max_attempts: 3)

    messages.each_with_index do |message, index|
      retry_handler.call do
        response = adapter.push_message(group_id, message)
        raise "働きかけ#{index + 1}つ目でエラー発生。#{message}" if response.code == '400'

        PrometheusMetrics.track_message_send('success')
      end
    end
  rescue StandardError => e
    Rails.logger.error("ReminderJob failed for #{group_id}: #{e.message}")
    PrometheusMetrics.track_message_send('error')
    raise
  end
end
