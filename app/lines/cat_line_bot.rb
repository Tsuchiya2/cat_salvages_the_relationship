module CatLineBot
  include MessageEvent

  private

  # ===== 設定関係 =====
  def set_client
    Line::Bot::Client.new do |config|
      config.channel_id = Rails.application.credentials.channel_id
      config.channel_secret = Rails.application.credentials.channel_secret
      config.channel_token = Rails.application.credentials.channel_token
    end
  end

  def request_body_read(request)
    request.body.read
  end

  def signature(request, client, body)
    # リクエストヘッダーのx-line-signatureに含まれる署名を検証(gem 'line-bot-api')
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    return head :bad_request unless client.validate_signature(body, signature)
  end

  # ===== 挙動関係 =====
  def line_bot_action(events, client)
    events.each do |event|
      parse_event(event, client)
    rescue StandardError => e
      group_id = current_group_id(event)
      error_message = "<Callback> 例外:#{e.class}, メッセージ:#{e.message}, バックトレース:#{e.backtrace}"
      LineMailer.error_email(group_id, error_message).deliver_later
    end
  end

  def parse_event(event, client)
    group_id = current_group_id(event)
    return one_on_one(event, client) if group_id.blank?

    json_data = count_members(event, client)
    count_menbers = JSON.parse(json_data.body)
    action_by_event_type(event, client, group_id, count_menbers)
  end

  def current_group_id(event)
    if event['source']['groupId']
      event['source']['groupId']    # LINE Botが加わっているグループIDを返す
    elsif event['source']['roomId']
      event['source']['roomId']     # LINE Botが加わっているトークルームIDを返す
    end
  end

  def count_members(event, client)
    if event['source']['groupId']
      client.get_group_members_count(event['source']['groupId'])    # LINE Botが加わっているグループ人数を返す
    elsif event['source']['roomId']
      client.get_room_members_count(event['source']['roomId'])      # LINE Botが加わっているトークルーム人数を返す
    end
  end

  def action_by_event_type(event, client, group_id, count_menbers)
    create_line_group(group_id, count_menbers)
    case event
    when Line::Bot::Event::Message
      message_events(event, client, group_id, count_menbers) # テキストメッセージは"おまじない"を含めて複雑化するため別に切り出しています。
    when Line::Bot::Event::Join, Line::Bot::Event::MemberJoined
      join_events(event, client, group_id)
    when Line::Bot::Event::Leave, Line::Bot::Event::MemberLeft
      leave_events(group_id, count_menbers)
    end
  end

  def create_line_group(group_id, count_menbers)
    return unless LineGroup.find_by(line_group_id: group_id).nil? && count_menbers['count'].to_i > 1

    LineGroup.create!(line_group_id: group_id, remind_at: Date.current.tomorrow,
                      status: :wait, member_count: count_menbers['count'].to_i)
  end

  def join_events(event, client, group_id)
    case event
    when Line::Bot::Event::Join
      message = { type: 'text',
                  text: '加えてくれてありがとうニャ🌟！！最後のLINEから3週間〜2ヶ月後にwake upのLINEするニャ！！（反応が無いとすぐかも知れニャンよ⏰）末永くよろしくニャ🐱🐾' }
    when Line::Bot::Event::MemberJoined
      message = { type: 'text',
                  text: '初めまして🌟ReLINE(https://www.cat-reline.com/)の"猫さん"っていうニャ🐱よろしくニャ🐾！！' }
    end
    client.push_message(group_id, message)
  end

  def leave_events(group_id, count_menbers)
    return if count_menbers['count'].to_i > 1 # "おまじない"が使用された際は、clientからの返り値は'{}'で、存在しないキーに'.to_i'を行うと'0'を返します。

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.destroy!
  end
end
