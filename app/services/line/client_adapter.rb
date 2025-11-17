# frozen_string_literal: true

module Line
  # Abstract interface for LINE Bot SDK operations
  #
  # This adapter pattern enables:
  # - Future SDK version upgrades without code changes
  # - Multi-platform support (LINE, Slack, Discord, etc.)
  # - Easy testing with mock adapters
  #
  # @abstract Subclass and implement all methods
  class ClientAdapter
    # Validate webhook signature using HMAC-SHA256
    #
    # @param body [String] Request body (raw string)
    # @param signature [String] X-Line-Signature header value
    # @return [Boolean] true if signature is valid
    # @raise [NotImplementedError] if not implemented by subclass
    def validate_signature(body, signature)
      raise NotImplementedError, "#{self.class} must implement #validate_signature"
    end

    # Parse webhook events from request body
    #
    # @param body [String] Request body (raw JSON string)
    # @return [Array<Line::Bot::Event>] Array of parsed events
    # @raise [NotImplementedError] if not implemented by subclass
    def parse_events(body)
      raise NotImplementedError, "#{self.class} must implement #parse_events"
    end

    # Push message to a target (group, room, or user)
    #
    # @param target [String] LINE group ID, room ID, or user ID
    # @param message [Hash] Message object (e.g., { type: 'text', text: 'Hello' })
    # @return [Object] Response object from LINE API
    # @raise [NotImplementedError] if not implemented by subclass
    def push_message(target, message)
      raise NotImplementedError, "#{self.class} must implement #push_message"
    end

    # Reply to a message using reply token
    #
    # @param reply_token [String] Reply token from webhook event
    # @param message [Hash] Message object
    # @return [Object] Response object from LINE API
    # @raise [NotImplementedError] if not implemented by subclass
    def reply_message(reply_token, message)
      raise NotImplementedError, "#{self.class} must implement #reply_message"
    end

    # Get member count for a group
    #
    # @param group_id [String] LINE group ID
    # @return [Integer] Number of members in the group
    # @raise [NotImplementedError] if not implemented by subclass
    def get_group_member_count(group_id)
      raise NotImplementedError, "#{self.class} must implement #get_group_member_count"
    end

    # Get member count for a room
    #
    # @param room_id [String] LINE room ID
    # @return [Integer] Number of members in the room
    # @raise [NotImplementedError] if not implemented by subclass
    def get_room_member_count(room_id)
      raise NotImplementedError, "#{self.class} must implement #get_room_member_count"
    end

    # Leave a group
    #
    # @param group_id [String] LINE group ID
    # @return [Object] Response object from LINE API
    # @raise [NotImplementedError] if not implemented by subclass
    def leave_group(group_id)
      raise NotImplementedError, "#{self.class} must implement #leave_group"
    end

    # Leave a room
    #
    # @param room_id [String] LINE room ID
    # @return [Object] Response object from LINE API
    # @raise [NotImplementedError] if not implemented by subclass
    def leave_room(room_id)
      raise NotImplementedError, "#{self.class} must implement #leave_room"
    end
  end

  # Concrete implementation for line-bot-sdk v2.x
  #
  # This adapter wraps the LINE Bot SDK client and provides:
  # - Metrics collection for all API calls
  # - Credential validation at initialization
  # - Automatic response parsing
  #
  # @example
  #   adapter = Line::SdkV2Adapter.new(
  #     channel_id: 'YOUR_CHANNEL_ID',
  #     channel_secret: 'YOUR_SECRET',
  #     channel_token: 'YOUR_TOKEN'
  #   )
  #   adapter.push_message('GROUP123', { type: 'text', text: 'Hello' })
  class SdkV2Adapter < ClientAdapter
    # Initialize adapter with LINE credentials
    #
    # @param credentials [Hash] LINE Bot credentials
    # @option credentials [String] :channel_id Channel ID
    # @option credentials [String] :channel_secret Channel Secret
    # @option credentials [String] :channel_token Channel Token
    # @raise [ArgumentError] if any credential is missing
    def initialize(credentials)
      @client = Line::Bot::Client.new do |config|
        config.channel_id = credentials[:channel_id]
        config.channel_secret = credentials[:channel_secret]
        config.channel_token = credentials[:channel_token]
      end

      validate_credentials(credentials)
    end

    # Validate webhook signature
    #
    # @param body [String] Request body
    # @param signature [String] X-Line-Signature header
    # @return [Boolean] true if signature is valid
    delegate :validate_signature, to: :@client

    # Parse events from webhook body
    #
    # @param body [String] Request body (JSON)
    # @return [Array<Line::Bot::Event>] Parsed events
    def parse_events(body)
      @client.parse_events_from(body)
    end

    # Push message to target with metrics tracking
    #
    # @param target [String] LINE group ID, room ID, or user ID
    # @param message [Hash] Message object
    # @return [Net::HTTPResponse] Response from LINE API
    def push_message(target, message)
      start_time = Time.current
      response = @client.push_message(target, message)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('push_message', response.code, duration)
      response
    end

    # Reply to message with metrics tracking
    #
    # @param reply_token [String] Reply token from event
    # @param message [Hash] Message object
    # @return [Net::HTTPResponse] Response from LINE API
    def reply_message(reply_token, message)
      start_time = Time.current
      response = @client.reply_message(reply_token, message)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('reply_message', response.code, duration)
      response
    end

    # Get group member count with metrics tracking
    #
    # @param group_id [String] LINE group ID
    # @return [Integer] Number of members
    def get_group_member_count(group_id)
      start_time = Time.current
      response = @client.get_group_members_count(group_id)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('get_group_members_count', '200', duration)
      response['count'].to_i
    end

    # Get room member count with metrics tracking
    #
    # @param room_id [String] LINE room ID
    # @return [Integer] Number of members
    def get_room_member_count(room_id)
      start_time = Time.current
      response = @client.get_room_members_count(room_id)
      duration = Time.current - start_time

      PrometheusMetrics.track_line_api_call('get_room_members_count', '200', duration)
      response['count'].to_i
    end

    # Leave a group
    #
    # @param group_id [String] LINE group ID
    # @return [Net::HTTPResponse] Response from LINE API
    delegate :leave_group, to: :@client

    # Leave a room
    #
    # @param room_id [String] LINE room ID
    # @return [Net::HTTPResponse] Response from LINE API
    delegate :leave_room, to: :@client

    private

    # Validate that all required credentials are present
    #
    # @param credentials [Hash] Credential hash
    # @raise [ArgumentError] if any credential is blank
    def validate_credentials(credentials)
      required = %i[channel_id channel_secret channel_token]
      missing = required.select { |key| credentials[key].blank? }

      raise ArgumentError, "Missing LINE credentials: #{missing.join(', ')}" if missing.any?
    end
  end
end
