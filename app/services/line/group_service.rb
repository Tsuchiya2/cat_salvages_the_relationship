# frozen_string_literal: true

module Line
  # Group lifecycle business logic service
  #
  # Manages LineGroup model CRUD operations including creation on bot join,
  # updates on message receipt, and cleanup on member departure.
  #
  # @example
  #   service = Line::GroupService.new(adapter)
  #   group = service.find_or_create('GROUP123', 5)
  #   service.update_record('GROUP123', 5)
  #   service.delete_if_empty('GROUP123', 1)
  class GroupService
    # Initialize group service with LINE adapter
    #
    # @param adapter [Line::ClientAdapter] LINE SDK adapter for API calls
    def initialize(adapter)
      @adapter = adapter
    end

    # Find existing group or create new one
    #
    # @param group_id [String] LINE group or room ID
    # @param member_count [Integer] Number of members in the group
    # @return [LineGroup, nil] Group record or nil if invalid
    def find_or_create(group_id, member_count)
      return nil if group_id.blank? || member_count < 2

      existing_group = LineGroup.find_by(line_group_id: group_id)
      return existing_group if existing_group

      create_group(group_id, member_count)
    end

    # Update group record on message receipt
    #
    # @param group_id [String] LINE group or room ID
    # @param member_count [Integer] Number of members in the group
    def update_record(group_id, member_count)
      return if member_count < 2

      line_group = LineGroup.find_by(line_group_id: group_id)
      return unless line_group

      line_group.update!(
        member_count: member_count,
        post_count: line_group.post_count + 1
      )
    end

    # Delete group if empty (member count <= 1)
    #
    # @param group_id [String] LINE group or room ID
    # @param member_count [Integer] Number of members in the group
    def delete_if_empty(group_id, member_count)
      return if member_count > 1

      line_group = LineGroup.find_by(line_group_id: group_id)
      line_group&.destroy!
    end

    # Send welcome message to group
    #
    # @param group_id [String] LINE group or room ID
    # @param message_type [Symbol] :join or :member_joined
    def send_welcome_message(group_id, message_type: :join)
      message = case message_type
                when :join
                  { type: 'text',
                    text: '加えてくれてありがとうニャ🌟！！最後のLINEから3週間〜2ヶ月後にwake upのLINEするニャ！！（反応が無いとすぐかも知れニャンよ⏰）末永くよろしくニャ🐱🐾' }
                when :member_joined
                  { type: 'text',
                    text: '初めまして🌟ReLINE(https://www.cat-reline.com/)の"猫さん"っていうニャ🐱よろしくニャ🐾！！' }
                end

      @adapter.push_message(group_id, message)
    end

    private

    # Create new group record
    def create_group(group_id, member_count)
      LineGroup.create!(
        line_group_id: group_id,
        remind_at: Date.current.tomorrow,
        status: :wait,
        member_count: member_count
      )
    end
  end
end
