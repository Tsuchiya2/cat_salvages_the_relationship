# Health check controller for monitoring
#
# Provides two endpoints:
# - GET /health - Shallow health check (fast, returns basic status)
# - GET /health/deep - Deep health check (slower, checks all dependencies)
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Shallow health check
  #
  # Returns basic application status without checking dependencies.
  # This endpoint should be fast and suitable for load balancer health checks.
  #
  # @example Response
  #   {
  #     "status": "ok",
  #     "version": "2.0.0",
  #     "timestamp": "2025-11-17T10:30:00Z"
  #   }
  def check
    render json: {
      status: 'ok',
      version: '2.0.0',
      timestamp: Time.current.iso8601
    }
  end

  # Deep health check
  #
  # Performs comprehensive health checks including:
  # - Database connectivity and latency
  # - LINE credentials validation
  #
  # Returns 200 OK if all checks pass, 503 Service Unavailable otherwise.
  #
  # @example Healthy Response (200 OK)
  #   {
  #     "status": "healthy",
  #     "checks": {
  #       "database": { "status": "healthy", "latency_ms": 5.23 },
  #       "line_credentials": { "status": "healthy" }
  #     },
  #     "timestamp": "2025-11-17T10:30:00Z"
  #   }
  #
  # @example Unhealthy Response (503 Service Unavailable)
  #   {
  #     "status": "unhealthy",
  #     "checks": {
  #       "database": { "status": "unhealthy", "error": "Connection refused" },
  #       "line_credentials": { "status": "healthy" }
  #     },
  #     "timestamp": "2025-11-17T10:30:00Z"
  #   }
  def deep
    checks = {
      database: check_database,
      line_credentials: check_line_credentials
    }

    all_healthy = checks.values.all? { |c| c[:status] == 'healthy' }
    status_code = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status_code
  end

  private

  # Check database connectivity
  #
  # @return [Hash] Health check result with status and latency
  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    latency_ms = ((Time.current - start_time) * 1000).round(2)

    { status: 'healthy', latency_ms: latency_ms }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  # Check LINE credentials availability
  #
  # @return [Hash] Health check result with status
  def check_line_credentials
    required = %i[channel_id channel_secret channel_token]
    present = required.all? { |key| Rails.application.credentials.send(key).present? }

    if present
      { status: 'healthy' }
    else
      { status: 'unhealthy', error: 'Missing LINE credentials' }
    end
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end
end
