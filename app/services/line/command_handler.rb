# frozen_string_literal: true

module Line
  # Command processing service
  #
  # Handles special text commands for bot removal and span settings.
  # Processes commands sent by users in group chats.
  #
  # @example
  #   handler = Line::CommandHandler.new(adapter)
  #   handler.handle_removal(event, 'GROUP123')
  #   handler.handle_span_setting(event, 'GROUP123')
  class CommandHandler
    REMOVAL_COMMAND = 'Cat sleeping on our Memory.'
    SPAN_FASTER = 'Would you set to faster.'
    SPAN_LATTER = 'Would you set to latter.'
    SPAN_DEFAULT = 'Would you set to default.'

    # Initialize command handler with LINE adapter
    #
    # @param adapter [Line::ClientAdapter] LINE SDK adapter for API calls
    def initialize(adapter)
      @adapter = adapter
    end

    # Handle bot removal command
    #
    # @param event [Line::Bot::Event::Message] Message event
    # @param group_id [String] LINE group or room ID
    def handle_removal(event, group_id)
      return unless event.message&.text == REMOVAL_COMMAND

      if event.source&.group_id
        @adapter.leave_group(group_id)
      elsif event.source&.room_id
        @adapter.leave_room(group_id)
      end
    end

    # Handle span setting command
    #
    # @param event [Line::Bot::Event::Message] Message event
    # @param group_id [String] LINE group or room ID
    def handle_span_setting(event, group_id)
      text = event.message&.text
      return unless span_command?(text)

      line_group = LineGroup.find_by(line_group_id: group_id)
      return unless line_group

      case text
      when SPAN_FASTER
        line_group.faster!
      when SPAN_LATTER
        line_group.latter!
      when SPAN_DEFAULT
        line_group.random!
      end

      send_confirmation(group_id)
    end

    # Check if text is a span command
    #
    # @param text [String] Message text
    # @return [Boolean] true if text is a span command
    def span_command?(text)
      text.in?([SPAN_FASTER, SPAN_LATTER, SPAN_DEFAULT])
    end

    private

    # Send confirmation message after span setting
    def send_confirmation(group_id)
      message = { type: 'text', text: '了解ニャ！次の投稿から設定を適応するニャ🐾！！' }
      @adapter.push_message(group_id, message)
    end
  end
end
