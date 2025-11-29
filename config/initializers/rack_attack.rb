# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and protection against brute force attacks
# Documentation: https://github.com/rack/rack-attack

module RackAttackConfig
  THROTTLED_HTML = <<~HTML
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

  class << self
    def log_throttle(request, match_data)
      Rails.logger.warn(
        "[Rack::Attack] Throttled: #{request.env['rack.attack.matched']} " \
        "IP=#{request.ip} Path=#{request.path} " \
        "Count=#{match_data[:count]}/#{match_data[:limit]} Period=#{match_data[:period]}s"
      )
    end

    def throttle_headers(match_data)
      now = match_data[:epoch_time]
      {
        'Content-Type' => 'text/html; charset=utf-8',
        'Retry-After' => (match_data[:period] - (now % match_data[:period])).to_s
      }
    end
  end
end

class Rack::Attack
  ### Throttle Spammy Clients ###
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  ### Prevent Brute-Force Login Attacks ###
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    req.ip if login_request?(req)
  end

  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    req.params.dig('operator_session', 'email').to_s.downcase.strip.presence if login_request?(req)
  end

  ### Prevent Brute-Force Password Reset Attacks ###
  throttle('password_resets/ip', limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == '/operator/password_resets' && req.post?
  end

  ### Safelist ###
  safelist('allow from localhost') do |req|
    ['127.0.0.1', '::1'].include?(req.ip)
  end

  ### Custom Responses ###
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    RackAttackConfig.log_throttle(request, match_data)
    [429, RackAttackConfig.throttle_headers(match_data), [RackAttackConfig::THROTTLED_HTML]]
  end

  self.blocklisted_responder = lambda do |request|
    Rails.logger.warn("[Rack::Attack] Blocked: IP=#{request.ip} Path=#{request.path}")
    [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']]
  end

  def self.login_request?(req)
    req.path == '/operator/cat_in' && req.post?
  end
end
