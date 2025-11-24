# frozen_string_literal: true

require 'yaml'

module DatabaseMigration
  # Configuration manager for database migrations
  # Loads configuration from YAML file and provides accessor methods
  class MigrationConfig
    CONFIG_FILE = 'config/database_migration.yml'

    attr_reader :config

    # Initializes migration configuration
    # @param overrides [Hash] configuration overrides
    def initialize(overrides = {})
      @config = load_config.deep_merge(symbolize_keys(overrides))
    end

    # Gets migration tool
    # @return [String, Symbol] migration tool name
    def migration_tool
      config.dig(:migration, :tool) || 'pgloader'
    end

    # Gets number of parallel workers
    # @return [Integer] number of workers
    def parallel_workers
      config.dig(:migration, :parallel_workers) || 8
    end

    # Gets verification threshold
    # @return [Integer] row count threshold
    def verification_threshold
      config.dig(:migration, :verification, :row_count_threshold) || 0
    end

    # Gets retry attempts
    # @return [Integer] number of retry attempts
    def retry_attempts
      config.dig(:migration, :verification, :retry_attempts) || 3
    end

    # Gets target downtime in minutes
    # @return [Integer] target downtime
    def target_downtime_minutes
      config.dig(:migration, :performance, :target_downtime_minutes) || 30
    end

    # Gets query timeout in milliseconds
    # @return [Integer] query timeout
    def query_timeout_ms
      config.dig(:migration, :performance, :query_timeout_ms) || 5000
    end

    # Checks if checksum verification is enabled
    # @return [Boolean] true if enabled
    def enable_checksum?
      config.dig(:migration, :verification, :enable_checksum) || false
    end

    # Converts configuration to hash
    # @return [Hash] configuration hash
    def to_h
      @config
    end

    private

    # Loads configuration from YAML file
    # @return [Hash] configuration hash
    def load_config
      config_path = Rails.root.join(CONFIG_FILE)

      if File.exist?(config_path)
        base_config = YAML.load_file(config_path)
        env_config = base_config[Rails.env] || base_config['default'] || {}
        symbolize_keys(env_config)
      else
        default_config
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to load migration config: #{e.message}. Using defaults."
      default_config
    end

    # Default configuration
    # @return [Hash] default configuration
    def default_config
      {
        migration: {
          tool: ENV.fetch('DB_MIGRATION_TOOL', 'pgloader'),
          parallel_workers: ENV.fetch('DB_MIGRATION_WORKERS', 8).to_i,
          verification: {
            row_count_threshold: ENV.fetch('DB_MIGRATION_ROW_COUNT_THRESHOLD', 0).to_i,
            retry_attempts: ENV.fetch('DB_MIGRATION_RETRY_ATTEMPTS', 3).to_i,
            enable_checksum: ENV.fetch('DB_MIGRATION_ENABLE_CHECKSUM', 'false') == 'true'
          },
          performance: {
            target_downtime_minutes: ENV.fetch('DB_MIGRATION_TARGET_DOWNTIME', 30).to_i,
            query_timeout_ms: ENV.fetch('DB_MIGRATION_QUERY_TIMEOUT', 5000).to_i
          }
        }
      }
    end

    # Recursively symbolizes hash keys
    # @param hash [Hash] hash to symbolize
    # @return [Hash] hash with symbolized keys
    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
      end
    end
  end
end
