# frozen_string_literal: true

# Health check controller for Kubernetes liveness/readiness probes
# and load balancer health checks
class HealthController < ActionController::API
  # GET /health
  # Basic liveness check - returns 200 if the app is running
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: Rails.application.class.module_parent_name
    }
  end

  # GET /health/deep
  # Deep health check - verifies database connectivity and other dependencies
  def deep
    checks = {
      database: check_database,
      disk_space: check_disk_space
    }

    status = checks.values.all? { |c| c[:status] == 'ok' } ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? 'ok' : 'degraded',
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: status
  end

  # GET /health/ready
  # Readiness check - returns 200 if the app is ready to receive traffic
  def ready
    if database_connected?
      render json: { status: 'ready', timestamp: Time.current.iso8601 }
    else
      render json: { status: 'not_ready', reason: 'database_unavailable' }, status: :service_unavailable
    end
  end

  private

  def check_database
    if database_connected?
      { status: 'ok', response_time_ms: measure_database_response_time }
    else
      { status: 'error', message: 'Database connection failed' }
    end
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def check_disk_space
    # Check if disk space is above 10% free
    stat = `df -h / | tail -1`.split
    usage_percent = stat[4].to_i

    if usage_percent < 90
      { status: 'ok', usage_percent: usage_percent }
    else
      { status: 'warning', usage_percent: usage_percent, message: 'Disk space low' }
    end
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def database_connected?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError
    false
  end

  def measure_database_response_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Base.connection.execute('SELECT 1')
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((end_time - start_time) * 1000).round(2)
  end
end
