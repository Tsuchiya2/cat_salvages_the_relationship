class Operator::WebhooksController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery except: :callback

  include CatLineBot

  def callback
    client = set_client
    body = request_body_read(request)
    signature(request, client, body)

    events = client.parse_events_from(body)
    line_bot_action(events, client)
    head :ok
  end
end
