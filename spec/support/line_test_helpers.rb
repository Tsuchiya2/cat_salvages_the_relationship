# frozen_string_literal: true

module LineTestHelpers
  def stub_line_credentials
    operator = double('operator')
    allow(operator).to receive(:[]).with(:email).and_return('test@example.com')

    credentials = double('credentials')
    allow(credentials).to receive_messages(channel_id: 'test_channel_id', channel_secret: 'test_channel_secret',
                                           channel_token: 'test_channel_token', operator: operator)

    allow(Rails.application).to receive(:credentials).and_return(credentials)
  end

  def create_line_message_event(group_id: 'GROUP123', text: 'Hello')
    {
      'type' => 'message',
      'replyToken' => 'REPLY_TOKEN',
      'source' => { 'type' => 'group', 'groupId' => group_id },
      'message' => { 'type' => 'text', 'text' => text }
    }
  end

  def create_line_join_event(group_id: 'GROUP123')
    {
      'type' => 'join',
      'replyToken' => 'REPLY_TOKEN',
      'source' => { 'type' => 'group', 'groupId' => group_id }
    }
  end

  def create_line_leave_event(group_id: 'GROUP123')
    {
      'type' => 'leave',
      'source' => { 'type' => 'group', 'groupId' => group_id }
    }
  end
end

RSpec.configure do |config|
  config.include LineTestHelpers
end
