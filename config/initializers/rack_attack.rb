# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and protection against brute force attacks
# Documentation: https://github.com/rack/rack-attack

class Rack::Attack
  # Configure cache store (uses Rails cache by default)
  # For production, consider using Redis:
  # Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_URL'])

  ### Throttle Spammy Clients ###

  # Throttle all requests by IP (300 requests per 5 minutes)
  # Only triggered for excessive request rates
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  ### Prevent Brute-Force Login Attacks ###

  # Throttle login attempts by IP address
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if login_request?(req)
      req.ip
    end
  end

  # Throttle login attempts by email parameter
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if login_request?(req)
      # Normalize email for consistent rate limiting
      req.params.dig('operator_session', 'email').to_s.downcase.strip.presence
    end
  end

  ### Prevent Brute-Force Password Reset Attacks ###

  # Throttle password reset requests by IP
  throttle('password_resets/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/operator/password_resets' && req.post?
      req.ip
    end
  end

  ### Custom Blocklist ###

  # Block requests from known bad IPs (optional)
  # blocklist('block bad IPs') do |req|
  #   # Load from database or Redis
  #   BlockedIp.exists?(ip: req.ip)
  # end

  ### Safelist ###

  # Always allow requests from localhost (development)
  safelist('allow from localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  ### Custom Response ###

  # Return a custom response when throttled
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'text/html; charset=utf-8',
      'Retry-After' => (match_data[:period] - (now % match_data[:period])).to_s
    }

    # Log throttle event for monitoring
    Rails.logger.warn(
      "[Rack::Attack] Throttled: #{request.env['rack.attack.matched']} " \
      "IP=#{request.ip} " \
      "Path=#{request.path} " \
      "Count=#{match_data[:count]}/#{match_data[:limit]} " \
      "Period=#{match_data[:period]}s"
    )

    # Track in Prometheus metrics if available
    if defined?(PrometheusExporter)
      # Increment throttle counter
    end

    [
      429, # Too Many Requests
      headers,
      [<<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Too Many Requests</title>
          <meta charset="utf-8">
          <style>
            body { font-family: sans-serif; text-align: center; padding: 50px; }
            h1 { color: #dc3545; }
          </style>
        </head>
        <body>
          <h1>429 Too Many Requests</h1>
          <p>リクエストが多すぎます。しばらくしてから再試行してください。</p>
          <p>Too many requests. Please try again later.</p>
        </body>
        </html>
      HTML
      ]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |request|
    Rails.logger.warn(
      "[Rack::Attack] Blocked: #{request.env['rack.attack.matched']} " \
      "IP=#{request.ip} Path=#{request.path}"
    )

    [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']]
  end

  # Helper method to identify login requests
  def self.login_request?(req)
    req.path == '/operator/cat_in' && req.post?
  end
end

# Instrument Rack::Attack events (for ActiveSupport::Notifications subscribers)
ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, _start, _finish, _request_id, payload|
  req = payload[:request]

  case name
  when 'throttle.rack_attack'
    Rails.logger.warn(
      "[Rack::Attack] Throttled request: " \
      "discriminator=#{req.env['rack.attack.match_discriminator']} " \
      "matched=#{req.env['rack.attack.matched']}"
    )
  when 'blocklist.rack_attack'
    Rails.logger.warn(
      "[Rack::Attack] Blocked request: " \
      "discriminator=#{req.env['rack.attack.match_discriminator']} " \
      "matched=#{req.env['rack.attack.matched']}"
    )
  end
end
