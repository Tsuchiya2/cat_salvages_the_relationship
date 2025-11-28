# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      # Request correlation
      correlation_id: RequestStore.store[:correlation_id],
      request_id: RequestStore.store[:request_id],

      # LINE webhook event fields
      group_id: event.payload[:group_id],
      event_type: event.payload[:event_type],

      # Authentication event fields
      user_id: event.payload[:user_id],
      user_email: event.payload[:user_email],
      result: event.payload[:result],
      reason: event.payload[:reason],

      # System info
      rails_version: Rails.version,
      sdk_version: '2.0.0',
      timestamp: Time.current.iso8601
    }
  end
end
