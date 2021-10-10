class Operator::CatchEventsController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery with: :null_session, only: %i[callback]

  require './app/line_bot_class/client'
  require './app/line_bot_class/request'
  require './app/line_bot_class/event'

  def callback
    client = Client.set_line_bot_client
    body = Request.request_body_read(request)
    Request.judge_bad_request(request, body, client)

    events = client.parse_events_from(body)
    events.each do |event|
      Event.event_routes(event, client)
      head :ok
    end
  end
end
