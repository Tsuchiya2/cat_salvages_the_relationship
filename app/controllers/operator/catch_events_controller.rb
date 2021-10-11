class Operator::CatchEventsController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery with: :null_session, only: %i[callback]

  require './app/line_bot_classes/manifest'

  def callback
    client = Client.set_line_bot_client
    body = Request.request_body_read(request)
    Request.judge_bad_request(request, body, client)

    events = client.parse_events_from(body)
    events.each do |event|
      begin
        Event.event_routes(event, client)
      rescue
        # メイラーで管理運営者に通知が行くようにする予定です。
      end
      head :ok
    end
  end
end
