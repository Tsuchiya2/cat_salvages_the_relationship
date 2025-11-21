# frozen_string_literal: true

module Line
  # Counts members in LINE groups and rooms
  #
  # Provides fallback handling for member counting with
  # graceful degradation on API failures.
  #
  # @example
  #   counter = Line::MemberCounter.new(adapter)
  #   count = counter.count(event)
  class MemberCounter
    # Initialize member counter
    #
    # @param adapter [Line::ClientAdapter] LINE client adapter
    def initialize(adapter)
      @adapter = adapter
    end

    # Count members for an event
    #
    # Returns fallback count if event source is unavailable
    # or API call fails.
    #
    # @param event [Line::Bot::Event] LINE event
    # @return [Integer] Member count
    def count(event)
      return fallback_count unless event.source

      if event.source.group_id
        count_for_group(event.source.group_id)
      elsif event.source.room_id
        count_for_room(event.source.room_id)
      else
        fallback_count
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to get member count: #{e.message}"
      fallback_count
    end

    private

    # Count members in a group
    #
    # @param group_id [String] Group ID
    # @return [Integer] Member count
    def count_for_group(group_id)
      Rails.cache.fetch("line:group:#{group_id}:member_count", expires_in: 5.minutes) do
        @adapter.get_group_member_count(group_id)
      end
    end

    # Count members in a room
    #
    # @param room_id [String] Room ID
    # @return [Integer] Member count
    def count_for_room(room_id)
      Rails.cache.fetch("line:room:#{room_id}:member_count", expires_in: 5.minutes) do
        @adapter.get_room_member_count(room_id)
      end
    end

    # Fallback member count for 1-on-1 chats
    #
    # @return [Integer] Default count (2)
    def fallback_count
      2
    end
  end
end
