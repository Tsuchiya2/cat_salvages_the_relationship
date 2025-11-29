class Operator::WebhooksController < Operator::BaseController
  skip_before_action :require_authentication, only: %i[callback]
  protect_from_forgery except: :callback

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']

    # Validate signature
    validator = Webhooks::SignatureValidator.new(Rails.application.credentials.channel_secret)
    return head :bad_request if signature.blank? || !validator.valid?(body, signature)

    # Parse events
    adapter = Line::ClientProvider.client
    events = adapter.parse_events(body)

    # Process events
    processor = build_event_processor(adapter)
    processor.process(events)

    PrometheusMetrics.track_webhook_request('success')
    head :ok
  rescue Timeout::Error
    PrometheusMetrics.track_webhook_request('timeout')
    head :service_unavailable
  rescue StandardError => e
    sanitizer = ErrorHandling::MessageSanitizer.new
    safe_message = sanitizer.sanitize(e.message)
    Rails.logger.error "Webhook processing failed: #{safe_message}"
    PrometheusMetrics.track_webhook_request('error')
    head :service_unavailable
  end

  private

  def build_event_processor(adapter)
    member_counter = Line::MemberCounter.new(adapter)
    group_service = Line::GroupService.new(adapter)
    command_handler = Line::CommandHandler.new(adapter)
    one_on_one_handler = Line::OneOnOneHandler.new(adapter)

    Line::EventProcessor.new(
      adapter: adapter,
      member_counter: member_counter,
      group_service: group_service,
      command_handler: command_handler,
      one_on_one_handler: one_on_one_handler
    )
  end
end
