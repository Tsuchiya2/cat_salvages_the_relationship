# Health check controller for monitoring
#
# Provides two endpoints:
# - GET /health - Shallow health check (fast, returns basic status)
# - GET /health/deep - Deep health check (slower, checks all dependencies)
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_monitor!, only: :deep, if: -> { Rails.env.production? }

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

  # Migration health check
  #
  # Checks the status of database migrations and database health.
  # This endpoint is specifically designed for monitoring migration progress.
  #
  # Returns 200 OK if database is healthy and migrations are current,
  # 503 Service Unavailable if database is unreachable,
  # 206 Partial Content if migration is in progress.
  #
  # @example Healthy Response (200 OK)
  #   {
  #     "status": "healthy",
  #     "checks": {
  #       "database_reachable": { "status": "healthy", "latency_ms": 5.23 },
  #       "migrations_current": { "status": "healthy", "pending_migrations": 0 },
  #       "sample_query_works": { "status": "healthy", "query_time_ms": 2.45 }
  #     },
  #     "migration_in_progress": false,
  #     "timestamp": "2025-11-24T10:30:00Z"
  #   }
  #
  # @example Migration In Progress Response (206 Partial Content)
  #   {
  #     "status": "migration_in_progress",
  #     "checks": {
  #       "database_reachable": { "status": "healthy", "latency_ms": 5.23 },
  #       "migrations_current": { "status": "in_progress", "pending_migrations": 5 },
  #       "sample_query_works": { "status": "healthy", "query_time_ms": 2.45 }
  #     },
  #     "migration_in_progress": true,
  #     "timestamp": "2025-11-24T10:30:00Z"
  #   }
  def migration
    checks = {
      database_reachable: check_database_reachable,
      migrations_current: check_migrations_current,
      sample_query_works: check_sample_query
    }

    migration_in_progress = checks[:migrations_current][:status] == 'in_progress'
    all_healthy = checks.values.all? { |c| c[:status] == 'healthy' }

    status_code = if !checks[:database_reachable][:status] == 'healthy'
                    :service_unavailable
                  elsif migration_in_progress
                    :partial_content
                  elsif all_healthy
                    :ok
                  else
                    :service_unavailable
                  end

    render json: {
      status: migration_in_progress ? 'migration_in_progress' : (all_healthy ? 'healthy' : 'unhealthy'),
      checks: checks,
      migration_in_progress: migration_in_progress,
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

  # Check if database is reachable
  #
  # @return [Hash] Health check result with status and latency
  def check_database_reachable
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    latency_ms = ((Time.current - start_time) * 1000).round(2)

    { status: 'healthy', latency_ms: latency_ms }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  # Check if migrations are current
  #
  # @return [Hash] Health check result with migration status
  def check_migrations_current
    # Get pending migrations
    pending = ActiveRecord::Base.connection.migration_context.needs_migration?

    if pending
      pending_count = ActiveRecord::Base.connection.migration_context.migrations.count
      { status: 'in_progress', pending_migrations: pending_count }
    else
      { status: 'healthy', pending_migrations: 0 }
    end
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  # Check if a sample query works
  #
  # @return [Hash] Health check result with query performance
  def check_sample_query
    start_time = Time.current

    # Perform a simple query (adjust based on your schema)
    # Using a safe query that should work on any database
    ActiveRecord::Base.connection.execute('SELECT 1 AS test')

    query_time_ms = ((Time.current - start_time) * 1000).round(2)

    { status: 'healthy', query_time_ms: query_time_ms }
  rescue StandardError => e
    { status: 'unhealthy', error: e.message }
  end

  def authenticate_monitor!
    username = ENV['MONITOR_USERNAME']
    password = ENV['MONITOR_PASSWORD']
    return head :forbidden if username.blank? || password.blank?

    authenticate_or_request_with_http_basic('Monitoring') do |user, pass|
      ActiveSupport::SecurityUtils.secure_compare(user, username) &&
        ActiveSupport::SecurityUtils.secure_compare(pass, password)
    end
  end
end
