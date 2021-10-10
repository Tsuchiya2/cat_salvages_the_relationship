class Client
  def self.set_line_bot_client
    client ||= Line::Bot::Client.new { |config|
      config.channel_id = Rails.application.credentials.channel_id
      config.channel_secret = Rails.application.credentials.channel_secret
      config.channel_token = Rails.application.credentials.channel_token
    }
  end
end
