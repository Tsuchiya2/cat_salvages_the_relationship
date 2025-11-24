# frozen_string_literal: true

require_relative 'strategy_factory'
require_relative 'migration_config'
require_relative '../database_adapter/factory'

module DatabaseMigration
  # Main migration framework orchestrator
  class Framework
    attr_reader :source, :target, :strategy, :config

    # Initializes the migration framework
    # @param source [String, Symbol] source adapter type
    # @param target [String, Symbol] target adapter type
    # @param strategy [DatabaseMigration::Strategies::Base, nil] migration strategy (optional)
    # @param config [Hash] configuration options
    def initialize(source:, target:, strategy: nil, config: {})
      @source = DatabaseAdapter::Factory.create(source, config[:source_config] || {})
      @target = DatabaseAdapter::Factory.create(target, config[:target_config] || {})
      @config = MigrationConfig.new(config)
      @strategy = strategy || infer_strategy
    end

    # Executes the complete migration process
    # @return [Hash] migration result
    def execute
      trace_migration('full_migration') do
        validate_prerequisites
        prepare
        migrate
        verify
        cleanup
      end
    end

    # Validates prerequisites before migration
    # @return [Hash] validation results
    def validate_prerequisites
      source_checks = @source.verify_compatibility
      target_checks = @target.verify_compatibility

      {
        source: source_checks,
        target: target_checks,
        all_passed: source_checks.values.all? && target_checks.values.all?
      }
    rescue StandardError => e
      raise MigrationError, "Prerequisite validation failed: #{e.message}"
    end

    # Prepares for migration
    # @return [Hash] preparation result
    def prepare
      log_migration_start

      @strategy.prepare(@source, @target)

      { status: 'prepared', timestamp: Time.current.iso8601 }
    rescue StandardError => e
      raise MigrationError, "Preparation failed: #{e.message}"
    end

    # Executes the migration
    # @return [Hash] migration result
    def migrate
      @strategy.migrate(@source, @target)
    rescue StandardError => e
      raise MigrationError, "Migration failed: #{e.message}"
    end

    # Verifies migration integrity
    # @return [Hash] verification results
    def verify
      # This will be implemented by data verifier (TASK-019)
      { status: 'verified', timestamp: Time.current.iso8601 }
    end

    # Cleans up after migration
    # @return [Hash] cleanup result
    def cleanup
      @strategy.cleanup

      { status: 'cleaned_up', timestamp: Time.current.iso8601 }
    rescue StandardError => e
      Rails.logger.warn "Cleanup warning: #{e.message}"
      { status: 'cleanup_warning', message: e.message }
    end

    private

    # Infers migration strategy based on source and target
    # @return [DatabaseMigration::Strategies::Base] strategy instance
    def infer_strategy
      StrategyFactory.create(
        source: @source.adapter_name,
        target: @target.adapter_name,
        config: @config.to_h
      )
    end

    # Logs migration start event
    def log_migration_start
      return unless defined?(Rails)

      Rails.logger.info(
        message: 'Database migration started',
        source_adapter: @source.adapter_name,
        target_adapter: @target.adapter_name,
        strategy: @strategy.class.name,
        timestamp: Time.current.iso8601
      )
    end

    # Traces migration operation (placeholder for OpenTelemetry)
    # @param operation [String] operation name
    # @yield block to execute
    def trace_migration(operation)
      # This will integrate with OpenTelemetry when available
      yield
    end
  end

  # Custom error class for migration errors
  class MigrationError < StandardError; end
end
