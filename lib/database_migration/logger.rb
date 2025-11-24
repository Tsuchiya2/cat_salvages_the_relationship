# frozen_string_literal: true

require 'semantic_logger'

module DatabaseMigration
  # Logger module for database migration operations
  #
  # Provides structured logging for migration events with JSON format.
  # All logs include metadata such as operation type, timestamp, and context.
  #
  # @example Logging a migration start
  #   DatabaseMigration::Logger.log_migration_start(
  #     migration_name: 'UnifyMySQL8Database',
  #     source_db: 'mysql2',
  #     target_db: 'mysql8'
  #   )
  #
  # @example Logging a table migration
  #   DatabaseMigration::Logger.log_table_migration(
  #     table_name: 'users',
  #     records_migrated: 1500,
  #     duration_ms: 234.56
  #   )
  module Logger
    class << self
      include SemanticLogger::Loggable

      # Log the start of a migration operation
      #
      # @param migration_name [String] Name of the migration
      # @param source_db [String] Source database identifier
      # @param target_db [String] Target database identifier
      # @param additional_context [Hash] Additional context to log
      # @return [void]
      def log_migration_start(migration_name:, source_db:, target_db:, **additional_context)
        logger.info(
          message: 'Migration started',
          event: 'migration_start',
          migration_name: migration_name,
          source_db: source_db,
          target_db: target_db,
          timestamp: Time.current.iso8601,
          **additional_context
        )

        # Write to separate migration log file
        write_to_migration_log(
          level: :info,
          event: 'migration_start',
          migration_name: migration_name,
          source_db: source_db,
          target_db: target_db,
          **additional_context
        )
      end

      # Log a table migration event
      #
      # @param table_name [String] Name of the table being migrated
      # @param records_migrated [Integer] Number of records migrated
      # @param duration_ms [Float] Duration of the migration in milliseconds
      # @param status [String] Status of the migration ('success', 'partial', 'failed')
      # @param additional_context [Hash] Additional context to log
      # @return [void]
      def log_table_migration(table_name:, records_migrated:, duration_ms:, status: 'success', **additional_context)
        log_level = status == 'failed' ? :error : :info

        logger.send(
          log_level,
          message: "Table migration #{status}",
          event: 'table_migration',
          table_name: table_name,
          records_migrated: records_migrated,
          duration_ms: duration_ms.round(2),
          status: status,
          timestamp: Time.current.iso8601,
          **additional_context
        )

        # Write to separate migration log file
        write_to_migration_log(
          level: log_level,
          event: 'table_migration',
          table_name: table_name,
          records_migrated: records_migrated,
          duration_ms: duration_ms.round(2),
          status: status,
          **additional_context
        )
      end

      # Log a migration error
      #
      # @param error [Exception] The error that occurred
      # @param context [Hash] Context information about where the error occurred
      # @return [void]
      def log_migration_error(error:, **context)
        logger.error(
          message: 'Migration error',
          event: 'migration_error',
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.first(5),
          timestamp: Time.current.iso8601,
          **context
        )

        # Write to separate migration log file
        write_to_migration_log(
          level: :error,
          event: 'migration_error',
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.first(5),
          **context
        )
      end

      # Log migration progress
      #
      # @param progress_percent [Float] Completion percentage (0-100)
      # @param current_step [String] Description of current step
      # @param additional_context [Hash] Additional context to log
      # @return [void]
      def log_migration_progress(progress_percent:, current_step:, **additional_context)
        logger.info(
          message: 'Migration progress update',
          event: 'migration_progress',
          progress_percent: progress_percent.round(2),
          current_step: current_step,
          timestamp: Time.current.iso8601,
          **additional_context
        )

        # Write to separate migration log file
        write_to_migration_log(
          level: :info,
          event: 'migration_progress',
          progress_percent: progress_percent.round(2),
          current_step: current_step,
          **additional_context
        )
      end

      # Log migration completion
      #
      # @param migration_name [String] Name of the migration
      # @param total_duration_ms [Float] Total duration in milliseconds
      # @param total_records [Integer] Total records migrated
      # @param status [String] Final status ('success', 'failed')
      # @param additional_context [Hash] Additional context to log
      # @return [void]
      def log_migration_complete(migration_name:, total_duration_ms:, total_records:, status: 'success', **additional_context)
        log_level = status == 'failed' ? :error : :info

        logger.send(
          log_level,
          message: "Migration #{status}",
          event: 'migration_complete',
          migration_name: migration_name,
          total_duration_ms: total_duration_ms.round(2),
          total_records: total_records,
          status: status,
          timestamp: Time.current.iso8601,
          **additional_context
        )

        # Write to separate migration log file
        write_to_migration_log(
          level: log_level,
          event: 'migration_complete',
          migration_name: migration_name,
          total_duration_ms: total_duration_ms.round(2),
          total_records: total_records,
          status: status,
          **additional_context
        )
      end

      private

      # Write log entry to separate migration log file
      #
      # @param level [Symbol] Log level (:info, :warn, :error)
      # @param data [Hash] Log data
      # @return [void]
      def write_to_migration_log(level:, **data)
        migration_logger = SemanticLogger['DatabaseMigration']
        migration_logger.send(level, data)
      end
    end
  end
end
