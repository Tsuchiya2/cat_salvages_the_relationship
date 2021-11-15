class Events::LineEvent
  require './app/lines/client_config'
  require './app/lines/request'
  require './app/lines/events/message_event'
  require './app/lines/events/join_event'
  require './app/lines/events/leave_event'
  extend Events::ClientConfig
  extend Events::Request
  extend Events::MessageEvent
  extend Events::JoinEvent
  extend Events::LeaveEvent

  def self.catch_events(events, client)
    events.each do |event|
      Events::LineEvent.callback_action(event, client)
    rescue StandardError => e
      group_id = Event.catch_group_or_room_id(event)
      error_message = "<Callback> 例外:#{e.class}, メッセージ:#{e.message}, バックトレース:#{e.backtrace}"
      Events::LineEvent.error_email(group_id, error_message).deliver_later
    end
  end

  def self.callback_action(event, client)
    group_id = Events::LineEvent.catch_group_or_room_id(event)
    return if group_id.blank?

    json_data = Events::LineEvent.count_group_members(event, client)
    count_menbers = JSON.parse(json_data.body)
    Events::LineEvent.branch_event_type(event, client, group_id, count_menbers)
  end

  def self.branch_event_type(event, client, group_id, count_menbers)
    case event
    when Line::Bot::Event::Message
      Events::LineEvent.catch_message(event, client, group_id, count_menbers)
    when Line::Bot::Event::Join
      Events::LineEvent.join_bot(client, group_id, count_menbers)
    when Line::Bot::Event::MemberJoined
      Events::LineEvent.join_member(client, group_id, count_menbers)
    when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
      Events::LineEvent.leave_events(group_id, count_menbers)
    end
  end

  def self.catch_group_or_room_id(event)
    if event['source']['groupId']
      event['source']['groupId']
    elsif event['source']['roomId']
      event['source']['roomId']
    end
  end

  def self.count_group_members(event, client)
    if event['source']['groupId']
      client.get_group_members_count(event['source']['groupId'])
    elsif event['source']['roomId']
      client.get_room_members_count(event['source']['roomId'])
    end
  end

  def self.create_line_group(group_id, count_menbers)
    return unless LineGroup.find_by(line_group_id: group_id).nil? && count_menbers['count'].to_i > 1

    LineGroup.create!(line_group_id: group_id, remind_at: Date.current.tomorrow,
                      status: :wait, member_count: count_menbers['count'].to_i)
  end
end
