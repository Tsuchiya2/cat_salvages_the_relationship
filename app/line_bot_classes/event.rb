class Event
  def self.events_processes(events, client)
    events.each do |event|
      Event.event_branches(event, client)
    rescue StandardError
      # メイラーで管理運営者に通知が行くようにする予定です。
    end
  end

  def self.event_branches(event, client)
    case event
    when Line::Bot::Event::Message
      Event.goodbye_cat(event, client) if event['message']['type'] == Line::Bot::Event::MessageType::Text
      Event.catch_message(event, client)
    when Line::Bot::Event::Join, Line::Bot::Event::MemberJoined
      Event.join_events(event, client)
    when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
      Event.leave_events(event, client)
    end
  end

  # +++++ ↓↓↓ LINE_Bot を退出させるおまじない ↓↓↓ +++++
  def self.goodbye_cat(event, client)
    group_id = Event.judge_group_or_room(event)
    return if group_id.blank?

    Event.cat_go_away(event, group_id, client) if event.message['text'].match?('I Love Cat.')
  end

  def self.cat_go_away(event, group_id, client)
    if event['source']['groupId']
      client.leave_group(group_id)
    elsif event['source']['roomId']
      client.leave_room(group_id)
    end
  end
  # +++++ ↑↑↑ LINE_Bot を退出させるおまじない ↑↑↑ +++++

  # ===== ↓↓↓ メンバーがテキスト・スタンプetcを送信した際、remind_at, status を更新します ↓↓↓ =====
  def self.catch_message(event, client)
    group_id = Event.judge_group_or_room(event)
    return if group_id.blank?

    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    return if count_menbers['count'].to_i < 2

    line_group = LineGroup.find_by(line_group_id: group_id)
    random_number = (23..60).to_a.sample
    line_group.update!(remind_at: Time.current.since(random_number.days), status: :wait)
  end
  # ===== ↑↑↑ メンバーがテキスト・スタンプetcを送信した際、remind_at, status を更新します ↑↑↑ =====

  # ***** ↓↓↓ メンバー or LINE_Bot が入室した際、人数によっては LineGroup を作成します ↓↓↓ *****
  def self.join_events(event, client)
    group_id = Event.judge_group_or_room(event)
    return if group_id.blank?

    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    if LineGroup.find_by(line_group_id: group_id).nil? && count_menbers['count'].to_i > 1
      LineGroup.create!(line_group_id: group_id, remind_at: Time.current.since(3.days), status: :call)
    end
    message = { type: 'text', text: '〇〇ニャ🐾よろしくニャ🐱🐾' }
    client.push_message(group_id, message)
  end
  # ***** ↑↑↑ メンバー or LINE_Bot が入室した際、人数によっては LineGroup を作成します ↑↑↑ *****

  # ----- ↓↓↓ メンバー or LINE_Bot が退出した際、残った人数によっては LineGroup を削除します ↓↓↓ -----
  def self.leave_events(event, client)
    group_id = Event.judge_group_or_room(event)
    return if group_id.blank?

    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    return if count_menbers['count'].to_i > 1 # LINE_Botが退出した際はclientからの返り値は'{}'で、登録されていないキーに'.to_i'を行うと'0'(nil)になります。

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.destroy!
  end
  # ----- ↑↑↑ メンバー or LINE_Bot が退出した際、残った人数によっては LineGroup を削除します ↑↑↑ -----

  # LINE_Bot が加わっている先が グループ or 複数人トークルーム かを判定。
  # どちらでもない場合は LINE_Bot と ユーザー になるので nil に設定。
  # (複数人トークルームはグループトークに統合：LINE みんなの使い方ガイドより)
  # https://guide.line.me/ja/friends-and-groups/create-groups.html
  def self.judge_group_or_room(event)
    if event['source']['groupId']
      event['source']['groupId']
    elsif event['source']['roomId']
      event['source']['roomId']
    end
  end

  # LINE_Bot が加わっている先のメンバー数をJSONで取得
  def self.members_count(event, client)
    if event['source']['groupId']
      client.get_group_members_count(event['source']['groupId'])
    elsif event['source']['roomId']
      client.get_room_members_count(event['source']['roomId'])
    end
  end

  # 機能確認用のオウム返し用コード - 最終的には削除する予定です。
  # def self.return_text(event, client)
  #   group_id = Event.judge_group_or_room(event)
  #   return if group_id.blank?

  #   message = { type: 'text', text: event.message['text'] }
  #   client.reply_message(event['replyToken'], message)
  # end
end
