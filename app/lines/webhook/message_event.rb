module Webhook::MessageEvent
  CHANGE_SPAN_WORDS = /Would you set to faster.|Would you set to latter.|Would you set to default./

  def catch_message(event, client, group_id, count_menbers)
    if event.message['text'].match?('Cat sleeping on our Memory.')
      Webhook::LineEvent.cat_back_memory(event, client, group_id)
    end
    Webhook::LineEvent.change_line_group_record(event, client, group_id, count_menbers)
  end

  def cat_back_memory(event, client, group_id)
    if event['source']['groupId']
      client.leave_group(group_id)
    elsif event['source']['roomId']
      client.leave_room(group_id)
    end
  end

  def change_line_group_record(event, client, group_id, count_menbers)
    return if count_menbers['count'].to_i < 2

    line_group = LineGroup.find_by(line_group_id: group_id)
    event.message['text'] ||= 'テキスト以外の通信です'
    if event.message['text'].match?(CHANGE_SPAN_WORDS)
      Webhook::LineEvent.change_set_span(event, line_group, client)
    else
      line_group.update_line_group_record(count_menbers['count'].to_i)
    end
  end

  def change_set_span(event, line_group, client)
    if event.message['text'].match?('Would you set to faster.')
      line_group.faster!
      Webhook::LineEvent.response_to_change_span_word(client, line_group)
    elsif event.message['text'].match?('Would you set to latter.')
      line_group.latter!
      Webhook::LineEvent.response_to_change_span_word(client, line_group)
    elsif event.message['text'].match?('Would you set to default.')
      line_group.random!
      Webhook::LineEvent.response_to_change_span_word(client, line_group)
    end
  end

  def response_to_change_span_word(client, line_group)
    message = { type: 'text', text: '了解ニャ！次の投稿から設定を適応するニャ🐾！！' }
    client.push_message(line_group.line_group_id, message)
  end
end
