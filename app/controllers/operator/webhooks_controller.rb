class Operator::WebhooksController < Operator::BaseController
  skip_before_action :require_login, only: %i[callback]
  protect_from_forgery except: :callback

  def callback
    client = CatLineBot.line_client_config
    body = request.body.read
    signature(request, client, body)

    events = client.parse_events_from(body)
    CatLineBot.line_bot_action(events, client)
    head :ok
  end

  private

  def signature(request, client, body)
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    return head :bad_request unless client.validate_signature(body, signature)
  end
end
