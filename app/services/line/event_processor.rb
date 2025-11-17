# frozen_string_literal: true

module Line
  # Core event processing orchestration service
  #
  # Handles all LINE webhook events with timeout protection, transaction management,
  # and idempotency tracking. Coordinates between event types and delegates to
  # specialized handler services.
  #
  # @example
  #   processor = Line::EventProcessor.new(
  #     adapter: adapter,
  #     member_counter: member_counter,
  #     group_service: group_service,
  #     command_handler: command_handler,
  #     one_on_one_handler: one_on_one_handler
  #   )
  #   processor.process(events)
  class EventProcessor
    PROCESSING_TIMEOUT = 8 # seconds

    # Initialize event processor with dependencies
    #
    # @param adapter [Line::ClientAdapter] LINE SDK adapter
    # @param member_counter [Line::MemberCounter] Member counting utility
    # @param group_service [Line::GroupService] Group lifecycle service
    # @param command_handler [Line::CommandHandler] Command processing service
    # @param one_on_one_handler [Line::OneOnOneHandler] 1-on-1 message handler
    def initialize(adapter:, member_counter:, group_service:, command_handler:, one_on_one_handler:)
      @adapter = adapter
      @member_counter = member_counter
      @group_service = group_service
      @command_handler = command_handler
      @one_on_one_handler = one_on_one_handler
      @processed_events = Set.new
    end

    # Process array of LINE webhook events
    #
    # @param events [Array<Line::Bot::Event>] Events from LINE webhook
    # @raise [Timeout::Error] if processing exceeds PROCESSING_TIMEOUT
    def process(events)
      Timeout.timeout(PROCESSING_TIMEOUT) do
        events.each do |event|
          process_single_event(event)
        rescue StandardError => e
          handle_error(e, event)
        end
      end
    rescue Timeout::Error
      Rails.logger.error "Webhook processing timeout after #{PROCESSING_TIMEOUT}s"
      raise
    end

    private

    # Process a single webhook event within a transaction
    def process_single_event(event)
      return if already_processed?(event)

      start_time = Time.current

      ActiveRecord::Base.transaction do
        group_id = extract_group_id(event)
        member_count = @member_counter.count(event)

        # Process event by type
        case event
        when Line::Bot::Event::Message
          process_message_event(event, group_id, member_count)
        when Line::Bot::Event::Join, Line::Bot::Event::MemberJoined
          process_join_event(event, group_id, member_count)
        when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
          process_leave_event(event, group_id, member_count)
        end

        mark_processed(event)
      end

      duration = Time.current - start_time
      PrometheusMetrics.track_webhook_duration(event.class.name, duration)
      PrometheusMetrics.track_event_success(event)
    end

    # Extract group ID from event source
    def extract_group_id(event)
      event.source&.group_id || event.source&.room_id
    end

    # Check if event has already been processed (idempotency)
    def already_processed?(event)
      event_id = generate_event_id(event)
      return true if @processed_events.include?(event_id)

      @processed_events.add(event_id)

      # Memory management: limit set size
      @processed_events.delete(@processed_events.first) if @processed_events.size > 10_000

      false
    end

    # Generate unique event ID for idempotency tracking
    def generate_event_id(event)
      "#{event.timestamp}-#{event.source&.group_id}-#{event.message&.id}"
    end

    # Mark event as processed (already in memory set)
    def mark_processed(_event)
      # Event is already in @processed_events set
    end

    # Handle processing errors
    def handle_error(exception, event)
      sanitizer = ErrorHandling::MessageSanitizer.new
      error_message = sanitizer.format_error(exception, 'Event Processing')

      Rails.logger.error(error_message)

      group_id = extract_group_id(event)
      LineMailer.error_email(group_id, error_message).deliver_later

      PrometheusMetrics.track_event_failure(event, exception)
    end

    # Process message events
    def process_message_event(event, group_id, member_count)
      # Handle 1-on-1 messages
      if group_id.blank?
        @one_on_one_handler.handle(event)
        return
      end

      # Handle commands
      @command_handler.handle_removal(event, group_id)
      @command_handler.handle_span_setting(event, group_id)

      # Update group record
      @group_service.update_record(group_id, member_count)
    end

    # Process join events (bot or member joined)
    def process_join_event(event, group_id, member_count)
      @group_service.find_or_create(group_id, member_count)

      message_type = event.is_a?(Line::Bot::Event::Join) ? :join : :member_joined
      @group_service.send_welcome_message(group_id, message_type: message_type)
    end

    # Process leave events (bot or member left)
    def process_leave_event(event, group_id, member_count)
      @group_service.delete_if_empty(group_id, member_count)
    end
  end
end
