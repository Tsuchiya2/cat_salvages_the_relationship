class Operator::CatchEventsController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery with: :null_session, only: %i[callback]

  require './app/lines/line_event'

  def callback
    # === リクエストがLINEプラットフォームから送信されたものかを確認します ====
    client = LineEvent.set_line_bot_client
    body = LineEvent.request_body_read(request)
    LineEvent.verify_request(request, body, client)

    # === 以下イベント毎の処理になります ===
    events = client.parse_events_from(body)
    LineEvent.catch_events(events, client)
    'OK'
  end
end
