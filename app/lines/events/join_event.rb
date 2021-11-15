module Events::JoinEvent
  def join_bot(client, group_id, count_menbers)
    Events::LineEvent.create_line_group(group_id, count_menbers)
    message = { type: 'text',
                text: '加えてくれてありがとうニャ🌟！！最後のLINEから3週間〜2ヶ月後にwake upのLINEするニャ！！（反応が無いとすぐかも知れニャンよ⏰）末永くよろしくニャ🐱🐾' }
    client.push_message(group_id, message)
  end

  def join_member(client, group_id, count_menbers)
    Events::LineEvent.create_line_group(group_id, count_menbers)
    message = { type: 'text', text: '初めまして🌟ReLINE(https://www.cat-reline.com/)の"猫さん"っていうニャ🐱よろしくニャ🐾！！' }
    client.push_message(group_id, message)
  end
end
