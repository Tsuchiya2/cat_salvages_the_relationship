class Event
  def self.event_routes(event, client)
    case event
    when Line::Bot::Event::Message
      Event.catch_message(event, client)
      # case event.type
      # when Line::Bot::Event::MessageType::Text
      #   Event.return_text(event, client)
      # end
    when Line::Bot::Event::Join
      Event.join_event(event, client)
    when Line::Bot::Event::Leave
      Event.leave_event(event)
    when Line::Bot::Event::MemberJoined
      Event.member_joined(event, client)
    when Line::Bot::Event::MemberLeft
      Event.member_left(event, client)
    end
  end

  # 2021/10/10 - self.catch_message：挙動をDB、各ラインアプリで確認。DBはremind_at, statusの変化を確認しました。 -
  def self.catch_message(event, client)
    group_id = event['source']['groupId']
    return if group_id.blank?

    json_data = client.get_group_members_count(group_id)
    count_menbers = JSON.parse(json_data.body)
    return if count_menbers['count'].to_i < 2

    line_group = LineGroup.find_by(line_group_id: group_id)
    random_number = (23..60).to_a.sample
    line_group.update!(remind_at: Time.current.since(random_number.days), status: :wait)
  end

  # # ====== 試験的に利用 ======
  # def self.return_text(event, client)
  #   message = { type: 'text', text: event.message['text'] }
  #   client.reply_message(event['replyToken'], message) if group_id.present?
  # end
  # # ====== 試験的に利用 ======

  # LINE_Botがグループに参加した際のアクション
  def self.join_event(event, client)
    group_id = event['source']['groupId']
    message = { type: 'text', text: '〇〇ニャ🐾よろしくニャ🐱🐾' }
    if group_id.present? && LineGroup.find_by(line_group_id: group_id).nil?
      LineGroup.create!(line_group_id: group_id, remind_at: Time.current.since(3.days), status: :call)
    end
    client.push_message(group_id, message)
  end

  # LINE_Botがグループから退出された際のアクション
  def self.leave_event(event)
    group_id = event['source']['groupId']
    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.delete!
  end

  # グループに新たにメンバーが参加した際のアクション
  def self.member_joined(event, client)
    group_id = event['source']['groupId']
    count_menbers = JSON.parse(client.get_group_members_count(group_id))
    unless count_menbers['count'].to_i > 1 && group_id.present? && LineGroup.find_by(line_group_id: group_id).nil?
      return
    end

    LineGroup.create!(line_group_id: group_id, remind_at: Time.current.since(3.days), status: :call)
  end

  # グループからメンバーが脱退した際のアクション
  def self.member_left(event, client)
    group_id = event['source']['groupId']
    count_menbers = JSON.parse(client.get_group_members_count(group_id))
    return unless count_menbers['count'].to_i < 2 && group_id.present?

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.delete!
  end
end
