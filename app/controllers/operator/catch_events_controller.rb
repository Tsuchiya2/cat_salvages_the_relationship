class Operator::CatchEventsController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery with: :null_session, only: %i[callback]

  require './app/lines/events/line_event'

  def callback
    # === リクエストがLINEプラットフォームから送信されたものかを確認します ====
    client = Events::LineEvent.set_line_bot_client
    body = Events::LineEvent.request_body_read(request)
    Events::LineEvent.verify_request(request, client, body)

    # === 以下イベント毎の処理になります ===
    events = client.parse_events_from(body)
    Events::LineEvent.catch_events(events, client)
    'OK'
  end
end
