# frozen_string_literal: true

require 'erb'
require 'cgi'

# Maintenance Middleware
#
# This middleware intercepts all requests when maintenance mode is enabled
# and returns a 503 Service Unavailable response with a maintenance page
class MaintenanceMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if MaintenanceMode.enabled?
      # Return 503 Service Unavailable with maintenance page
      [503, { 'Content-Type' => 'text/html; charset=utf-8' }, [maintenance_page]]
    else
      # Pass through to the application
      @app.call(env)
    end
  end

  private

  # Generates the HTML maintenance page using ERB template
  # @return [String] HTML content
  def maintenance_page
    custom_message = MaintenanceMode.message || MaintenanceMode.default_message
    template_path = Rails.root.join('app/views/maintenance/index.html.erb')

    # Variables accessible in the template
    message = CGI.escapeHTML(custom_message)
    timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')

    # Render ERB template
    template = File.read(template_path)
    ERB.new(template).result(binding)
  rescue StandardError => e
    # Fallback to simple HTML if template fails
    Rails.logger.error "Failed to load maintenance template: #{e.message}"
    fallback_maintenance_page
  end

  # Fallback maintenance page if template loading fails
  # @return [String] Simple HTML content
  def fallback_maintenance_page
    <<~HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>System Maintenance</title>
      </head>
      <body>
        <h1>System Maintenance</h1>
        <p>The system is currently under maintenance. Please try again later.</p>
      </body>
      </html>
    HTML
  end
end
