module MessageEvent
  extend ActiveSupport::Concern

  HOW_TO_USE = 'https://www.cat-reline.com/'.freeze
  CHANGE_SPAN_WORDS = /Would you set to faster.|Would you set to latter.|Would you set to default./

  def message_events(event, client, group_id, count_menbers)
    cat_back_to_memory(event, client, group_id) if event.message['text']&.match?('Cat sleeping on our Memory.')
    update_line_group_record(event, client, group_id, count_menbers)
  end

  def cat_back_to_memory(event, client, group_id)
    if event['source']['groupId']
      client.leave_group(group_id)    # グループからLINE Bot退出
    elsif event['source']['roomId']
      client.leave_room(group_id)     # トークルームからLINE Bot退出
    end
  end

  def update_line_group_record(event, client, group_id, count_menbers)
    return if count_menbers['count'].to_i < 2

    line_group = LineGroup.find_by(line_group_id: group_id)
    event.message['text'] ||= 'テキスト以外の通信です'
    if event.message['text'].match?(CHANGE_SPAN_WORDS)
      update_set_span(event, line_group, client)
    else
      line_group.update_record(count_menbers['count'].to_i)
    end
  end

  def update_set_span(event, line_group, client)
    if event.message['text'].match?('Would you set to faster.')
      line_group.faster!
    elsif event.message['text'].match?('Would you set to latter.')
      line_group.latter!
    elsif event.message['text'].match?('Would you set to default.')
      line_group.random!
    end
    response_to_change_span_word(client, line_group)
  end

  def response_to_change_span_word(client, line_group)
    message = { type: 'text', text: '了解ニャ！次の投稿から設定を適応するニャ🐾！！' }
    client.push_message(line_group.line_group_id, message)
  end

  # === 1on1の場合 ===``
  def one_on_one(event, client)
    message = case event.type
              when Line::Bot::Event::MessageType::Text
                { type: 'text', text: "【ReLINE】の使い方はこちらで確認してほしいにゃ！🐱🐾#{HOW_TO_USE}" }
              when Line::Bot::Event::MessageType::Sticker
                { type: 'text', text: "スタンプありがとうニャ！✨\nお礼にこちらをお送りするニャ🐾🐾\n#{Content.free.sample.body}" }
              else
                { type: 'text', text: 'ごめんニャ😿分からないニャ。。。' }
              end
    client.reply_message(event['replyToken'], message)
  end
end
