# frozen_string_literal: true

# DatabaseMetrics module for tracking database-related metrics
#
# This module provides methods to update and track database metrics
# for Prometheus monitoring. It tracks connection pool usage, query
# performance, and migration progress.
#
# @example Update pool metrics
#   DatabaseMetrics.update_pool_metrics
#
# @example Record query duration
#   DatabaseMetrics.record_query('SELECT', 0.123)
module DatabaseMetrics
  class << self
    # Update database connection pool metrics
    #
    # Reads current connection pool statistics from ActiveRecord and
    # updates Prometheus gauges. Should be called periodically (e.g., every 10s).
    #
    # @return [void]
    def update_pool_metrics
      return unless defined?(ActiveRecord::Base)

      pool = ActiveRecord::Base.connection_pool

      # Update pool size metrics
      DATABASE_POOL_SIZE.set(pool.size)
      DATABASE_POOL_AVAILABLE.set(pool.connections.count { |c| !c.in_use? })

      # Calculate waiting threads (if available)
      waiting = pool.num_waiting_in_queue if pool.respond_to?(:num_waiting_in_queue)
      DATABASE_POOL_WAITING.set(waiting || 0)
    rescue StandardError => e
      Rails.logger.error("Failed to update pool metrics: #{e.message}")
    end

    # Record database query duration
    #
    # Records the duration of a database query in the histogram metric.
    # Operation type helps identify slow query patterns.
    #
    # @param operation [String] Type of operation ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
    # @param duration_seconds [Float] Query duration in seconds
    # @return [void]
    def record_query(operation, duration_seconds)
      DATABASE_QUERY_DURATION.observe(duration_seconds, labels: { operation: operation.upcase })
    rescue StandardError => e
      Rails.logger.error("Failed to record query metric: #{e.message}")
    end

    # Update migration progress percentage
    #
    # Updates the gauge showing migration completion percentage.
    #
    # @param percent [Float] Completion percentage (0-100)
    # @return [void]
    def update_migration_progress(percent)
      MIGRATION_PROGRESS_PERCENT.set(percent.clamp(0, 100))
    rescue StandardError => e
      Rails.logger.error("Failed to update migration progress: #{e.message}")
    end

    # Increment migration error counter
    #
    # Increments the counter for migration errors, labeled by error type.
    #
    # @param error_type [String] Type of error ('connection', 'timeout', 'data', 'unknown')
    # @return [void]
    def increment_migration_error(error_type)
      MIGRATION_ERRORS_TOTAL.increment(labels: { error_type: error_type })
    rescue StandardError => e
      Rails.logger.error("Failed to increment migration error: #{e.message}")
    end

    # Get current pool statistics as hash
    #
    # Returns current connection pool statistics for logging or debugging.
    #
    # @return [Hash] Pool statistics
    def pool_stats
      return {} unless defined?(ActiveRecord::Base)

      pool = ActiveRecord::Base.connection_pool

      {
        size: pool.size,
        connections: pool.connections.size,
        available: pool.connections.count { |c| !c.in_use? },
        in_use: pool.connections.count(&:in_use?),
        waiting: pool.respond_to?(:num_waiting_in_queue) ? pool.num_waiting_in_queue : 0
      }
    rescue StandardError => e
      Rails.logger.error("Failed to get pool stats: #{e.message}")
      {}
    end

    # Start periodic pool metrics update background thread
    #
    # Starts a thread that updates pool metrics every 10 seconds.
    # This should be called during application initialization.
    #
    # @return [Thread] The background thread
    def start_periodic_metrics_update
      Thread.new do
        loop do
          update_pool_metrics
          sleep 10
        rescue StandardError => e
          Rails.logger.error("Error in metrics update thread: #{e.message}")
          sleep 10 # Continue even if error occurs
        end
      end
    end
  end
end

# Subscribe to ActiveSupport SQL notifications to track query duration
ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, start, finish, _id, payload|
  duration = finish - start
  sql = payload[:sql]

  # Determine operation type from SQL
  operation = case sql
              when /^\s*SELECT/i then 'SELECT'
              when /^\s*INSERT/i then 'INSERT'
              when /^\s*UPDATE/i then 'UPDATE'
              when /^\s*DELETE/i then 'DELETE'
              else 'OTHER'
              end

  DatabaseMetrics.record_query(operation, duration)
end

# Start periodic metrics update in production
if Rails.env.production?
  Rails.application.config.after_initialize do
    DatabaseMetrics.start_periodic_metrics_update
  end
end
