class Operator::CatchEventsController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery with: :null_session, only: %i[callback]

  require './app/lines/manifest'

  def callback
    # === リクエストがLINEプラットフォームから送信されたものかを確認します ====
    client = ClientConfig.set_line_bot_client
    body = Request.request_body_read(request)
    Request.judge_bad_request(request, body, client)

    # === 以下イベント毎の処理になります ===
    events = client.parse_events_from(body)
    Event.events_processes(events, client)
    'OK'
  end
end
