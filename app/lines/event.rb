class Event
  def self.events_processes(events, client)
    events.each do |event|
      Event.event_branches(event, client)
    rescue StandardError => e
      group_id = Event.judge_group_or_room(event)
      error_message = "<Callback> 例外:#{e.class}, メッセージ:#{e.message}"
      LineMailer.error_email(group_id, error_message).deliver_later
    end
  end

  def self.event_branches(event, client)
    group_id = Event.judge_group_or_room(event)
    return if group_id.blank?

    case event
    when Line::Bot::Event::Message
      Event.goodbye_cat(event, client, group_id) if event['message']['type'] == Line::Bot::Event::MessageType::Text
      Event.catch_message(event, client, group_id)
    when Line::Bot::Event::Join
      Event.join_bot(event, client, group_id)
    when Line::Bot::Event::MemberJoined
      Event.join_member(event, client, group_id)
    when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
      Event.leave_events(event, client, group_id)
    end
  end

  # LINE_Bot が加わっている先が グループ or 複数人トークルーム かを判定。
  # https://guide.line.me/ja/friends-and-groups/create-groups.html
  def self.judge_group_or_room(event)
    if event['source']['groupId']
      event['source']['groupId']
    elsif event['source']['roomId']
      event['source']['roomId']
    end
  end

  # [イベント] ===== ↓↓↓ LINE_Bot を退出させる"おまじない" ↓↓↓ =====
  def self.goodbye_cat(event, client, group_id)
    Event.cat_go_away(event, client, group_id) if event.message['text'].match?('Cat sleeping on our Memory.')
  end

  #  "おまじない"を受けてLINE Botを退出させるリクエストを飛ばします
  def self.cat_go_away(event, client, group_id)
    if event['source']['groupId']
      client.leave_group(group_id)
    elsif event['source']['roomId']
      client.leave_room(group_id)
    end
  end

  # [イベント] ===== ↓↓↓ メンバーがテキスト・スタンプetcを送信した際、remind_at, status を更新します ↓↓↓ =====
  def self.catch_message(event, client, group_id)
    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    return if count_menbers['count'].to_i < 2

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.change_status_to_wait(count_menbers['count'].to_i)
  end

  # [イベント] ===== ↓↓↓ LINE_Bot が入室した際、人数によっては LineGroup を作成します ↓↓↓ =====
  def self.join_bot(event, client, group_id)
    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    Event.create_line_group(group_id, count_menbers)
    message = { type: 'text',
                text: '加えてくれてありがとうニャ🌟！！最後のLINEから3週間〜2ヶ月後にwake upのLINEするニャ！！（反応が無いとすぐwake upするかも知れニャンよ⏰）末永くよろしくニャ🐱🐾' }
    client.push_message(group_id, message)
  end

  # [イベント] ===== ↓↓↓ メンバー が新しく入室した際、人数によっては LineGroup を作成します ↓↓↓ =====
  def self.join_member(event, client, group_id)
    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    Event.create_line_group(group_id, count_menbers)
    message = { type: 'text', text: '初めまして🌟ReLINE(https://www.cat-reline.com/)の"猫さん"っていうニャ🐱よろしくニャ🐾！！' }
    client.push_message(group_id, message)
  end

  # [イベント] ===== ↓↓↓ メンバー or LINE_Bot が退出した際、残った人数によっては LineGroup を削除します ↓↓↓ =====
  def self.leave_events(event, client, group_id)
    json_data = Event.members_count(event, client)
    count_menbers = JSON.parse(json_data.body)
    return if count_menbers['count'].to_i > 1 # "おまじない"が使用された際は、clientからの返り値は'{}'で、存在しないキーに'.to_i'を行うと'0'を返します。

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.destroy!
  end

  # LINE_Bot が加わっている先のメンバー数を取得
  def self.members_count(event, client)
    if event['source']['groupId']
      client.get_group_members_count(event['source']['groupId'])
    elsif event['source']['roomId']
      client.get_room_members_count(event['source']['roomId'])
    end
  end

  # LineGroupsテーブルにレコードが無く、且つメンバーが2人以上の際に新しくレコードを作成する
  def self.create_line_group(group_id, count_menbers)
    return unless LineGroup.find_by(line_group_id: group_id).nil? && count_menbers['count'].to_i > 1

    LineGroup.create!(line_group_id: group_id, remind_at: Date.current.tomorrow,
                      status: :wait, member_count: count_menbers['count'].to_i)
  end
end
