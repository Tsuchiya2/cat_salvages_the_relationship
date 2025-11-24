# frozen_string_literal: true

require 'opentelemetry/sdk'

module DatabaseMigration
  # Tracing module for database migration operations
  #
  # Provides distributed tracing capabilities for migration operations using OpenTelemetry.
  # Creates spans for major migration events to track performance and identify bottlenecks.
  #
  # @example Trace a migration operation
  #   DatabaseMigration::Tracing.trace_migration('UnifyMySQL8Database') do |span|
  #     # Perform migration
  #     span.add_event('Started table migration', attributes: { table: 'users' })
  #     # ...
  #     span.set_attribute('records.migrated', 1000)
  #   end
  module Tracing
    class << self
      # Get the OpenTelemetry tracer instance
      #
      # @return [OpenTelemetry::Trace::Tracer] Tracer instance
      def tracer
        @tracer ||= OpenTelemetry.tracer_provider.tracer('database_migration', '1.0.0')
      end

      # Trace a migration operation
      #
      # Creates a span for the entire migration operation. Use this for top-level
      # migration tracking.
      #
      # @param migration_name [String] Name of the migration
      # @param attributes [Hash] Additional span attributes
      # @yield [span] Yields the span for adding events and attributes
      # @return [Object] The result of the block
      #
      # @example
      #   result = DatabaseMigration::Tracing.trace_migration('UnifyMySQL8Database') do |span|
      #     span.set_attribute('source_db', 'mysql2')
      #     span.set_attribute('target_db', 'mysql8')
      #     perform_migration
      #   end
      def trace_migration(migration_name, attributes: {})
        tracer.in_span(
          'database_migration.execute',
          attributes: {
            'migration.name' => migration_name,
            'operation' => 'migration',
            'timestamp' => Time.current.iso8601
          }.merge(attributes),
          kind: :internal
        ) do |span|
          result = yield(span)
          span.set_attribute('status', 'success')
          result
        rescue StandardError => e
          span.record_exception(e)
          span.set_attribute('status', 'error')
          span.set_attribute('error.type', e.class.name)
          span.set_attribute('error.message', e.message)
          raise
        end
      end

      # Trace a table migration operation
      #
      # Creates a span for migrating a single table. Use this within a migration span.
      #
      # @param table_name [String] Name of the table being migrated
      # @param attributes [Hash] Additional span attributes
      # @yield [span] Yields the span for adding events and attributes
      # @return [Object] The result of the block
      #
      # @example
      #   DatabaseMigration::Tracing.trace_table_migration('users') do |span|
      #     span.set_attribute('records.count', User.count)
      #     migrate_table_data
      #   end
      def trace_table_migration(table_name, attributes: {})
        tracer.in_span(
          'database_migration.migrate_table',
          attributes: {
            'table.name' => table_name,
            'operation' => 'table_migration',
            'timestamp' => Time.current.iso8601
          }.merge(attributes),
          kind: :internal
        ) do |span|
          start_time = Time.current

          result = yield(span)

          duration_ms = ((Time.current - start_time) * 1000).round(2)
          span.set_attribute('duration_ms', duration_ms)
          span.set_attribute('status', 'success')
          result
        rescue StandardError => e
          span.record_exception(e)
          span.set_attribute('status', 'error')
          span.set_attribute('error.type', e.class.name)
          span.set_attribute('error.message', e.message)
          raise
        end
      end

      # Trace a database query operation
      #
      # Creates a span for a database query. Use this to track specific queries
      # within migration operations.
      #
      # @param query_type [String] Type of query (SELECT, INSERT, UPDATE, DELETE)
      # @param attributes [Hash] Additional span attributes
      # @yield [span] Yields the span for adding events and attributes
      # @return [Object] The result of the block
      #
      # @example
      #   DatabaseMigration::Tracing.trace_query('INSERT') do |span|
      #     span.set_attribute('records.inserted', 100)
      #     bulk_insert_records
      #   end
      def trace_query(query_type, attributes: {})
        tracer.in_span(
          'database_migration.query',
          attributes: {
            'db.operation' => query_type.upcase,
            'operation' => 'query',
            'timestamp' => Time.current.iso8601
          }.merge(attributes),
          kind: :client
        ) do |span|
          start_time = Time.current

          result = yield(span)

          duration_ms = ((Time.current - start_time) * 1000).round(2)
          span.set_attribute('duration_ms', duration_ms)
          span.set_attribute('status', 'success')
          result
        rescue StandardError => e
          span.record_exception(e)
          span.set_attribute('status', 'error')
          span.set_attribute('error.type', e.class.name)
          span.set_attribute('error.message', e.message)
          raise
        end
      end

      # Add a span event
      #
      # Adds an event to the current active span with attributes.
      #
      # @param event_name [String] Name of the event
      # @param attributes [Hash] Event attributes
      # @return [void]
      #
      # @example
      #   DatabaseMigration::Tracing.add_event('checkpoint_reached', progress: 50)
      def add_event(event_name, attributes: {})
        span = OpenTelemetry::Trace.current_span
        return unless span.recording?

        span.add_event(
          event_name,
          attributes: attributes.merge(timestamp: Time.current.iso8601)
        )
      end

      # Set attribute on current span
      #
      # Sets an attribute on the current active span.
      #
      # @param key [String] Attribute key
      # @param value [Object] Attribute value
      # @return [void]
      #
      # @example
      #   DatabaseMigration::Tracing.set_attribute('records.migrated', 1000)
      def set_attribute(key, value)
        span = OpenTelemetry::Trace.current_span
        return unless span.recording?

        span.set_attribute(key, value)
      end

      # Record exception on current span
      #
      # Records an exception on the current active span.
      #
      # @param exception [Exception] The exception to record
      # @return [void]
      #
      # @example
      #   begin
      #     # operation
      #   rescue => e
      #     DatabaseMigration::Tracing.record_exception(e)
      #     raise
      #   end
      def record_exception(exception)
        span = OpenTelemetry::Trace.current_span
        return unless span.recording?

        span.record_exception(exception)
        span.set_attribute('error', true)
        span.set_attribute('error.type', exception.class.name)
        span.set_attribute('error.message', exception.message)
      end

      # Check if tracing is enabled
      #
      # @return [Boolean] True if tracing is enabled
      def enabled?
        defined?(OpenTelemetry) && OpenTelemetry.tracer_provider.is_a?(OpenTelemetry::SDK::Trace::TracerProvider)
      end
    end
  end
end
