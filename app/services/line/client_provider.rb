# frozen_string_literal: true

require_relative 'client_adapter'

module Line
  # Client provider for LINE Bot SDK adapter
  #
  # This singleton provides a memoized instance of the LINE client adapter
  # with credentials loaded from Rails encrypted credentials.
  #
  # Benefits:
  # - Single client instance (reduces memory overhead)
  # - Centralized credential management
  # - Easy testing with reset! method
  #
  # @example
  #   # Get client instance
  #   client = Line::ClientProvider.client
  #   client.push_message('GROUP123', { type: 'text', text: 'Hello' })
  #
  #   # Reset for testing
  #   Line::ClientProvider.reset!
  class ClientProvider
    class << self
      # Get or create LINE client adapter instance
      #
      # @return [Line::SdkV2Adapter] Memoized client adapter
      def client
        @client ||= SdkV2Adapter.new(
          channel_id: Rails.application.credentials.channel_id,
          channel_secret: Rails.application.credentials.channel_secret,
          channel_token: Rails.application.credentials.channel_token
        )
      end

      # Reset client instance (primarily for testing)
      #
      # @return [nil]
      def reset!
        @client = nil
      end
    end
  end
end
