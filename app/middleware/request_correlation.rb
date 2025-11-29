# frozen_string_literal: true

# Request Correlation Middleware
#
# Injects or generates a unique request_id for each HTTP request,
# stores it in RequestStore for propagation across the request lifecycle.
#
# This enables correlation of logs, metrics, and background jobs
# for observability and debugging.
#
# @example Request with X-Request-ID header
#   GET /api/operators HTTP/1.1
#   X-Request-ID: abc-123-def-456
#
#   # request_id = 'abc-123-def-456' (from header)
#
# @example Request without X-Request-ID header
#   GET /api/operators HTTP/1.1
#
#   # request_id = 'generated-uuid' (auto-generated)
class RequestCorrelation
  def initialize(app)
    @app = app
  end

  # Process request and inject/generate request_id
  #
  # @param env [Hash] Rack environment
  # @return [Array] Rack response [status, headers, body]
  def call(env)
    # Extract request_id from X-Request-ID header or generate UUID
    request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    # Store in RequestStore for propagation
    RequestStore.store[:request_id] = request_id
    RequestStore.store[:correlation_id] = request_id # Alias for LINE webhook compatibility

    @app.call(env)
  ensure
    # Clear RequestStore to prevent leakage between requests
    RequestStore.clear!
  end
end
