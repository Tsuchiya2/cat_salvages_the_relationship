class Event
  require 'line/bot'

  def self.event_routes(event, client)
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        Event.oumugaeshi(event, client)
      end
    end
  end


  def self.oumugaeshi(event, client)
    message = { type: 'text', text: event.message['text'] }
    client.reply_message(event['replyToken'], message)
  end
end
