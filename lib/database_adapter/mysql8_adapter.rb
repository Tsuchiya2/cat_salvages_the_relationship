# frozen_string_literal: true

require_relative 'base'

module DatabaseAdapter
  # MySQL 8 adapter implementation
  class MySQL8Adapter < Base
    MINIMUM_VERSION = '8.0.0'
    RECOMMENDED_VERSION = '8.0.34'

    # Returns the adapter name
    # @return [String] 'mysql2'
    def adapter_name
      'mysql2'
    end

    # Migrates data from source adapter
    # @param source_adapter [DatabaseAdapter::Base] source adapter
    # @param options [Hash] migration options
    # @return [Hash] migration result
    def migrate_from(source_adapter, options = {})
      case source_adapter.adapter_name
      when 'postgresql'
        require_relative '../database_migration/strategies/postgresql_to_mysql8_strategy'
        DatabaseMigration::Strategies::PostgreSQLToMySQL8Strategy.new(@config.merge(options)).migrate(source_adapter, self)
      else
        raise "Unsupported migration path from #{source_adapter.adapter_name} to MySQL 8"
      end
    end

    # Verifies MySQL 8 compatibility
    # @return [Hash] compatibility check results
    def verify_compatibility
      checks = {
        version_check: version_supported?,
        encoding_check: encoding_compatible?,
        features_check: required_features_available?
      }

      unless checks.values.all?
        raise CompatibilityError, "Compatibility checks failed: #{checks}"
      end

      checks
    end

    # Returns connection parameters for MySQL 8
    # @return [Hash] connection parameters
    def connection_params
      {
        adapter: 'mysql2',
        encoding: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci',
        pool: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
        timeout: 5000,
        reconnect: true
      }.merge(@config)
    end

    protected

    # Returns the MySQL version
    # @return [String] MySQL version string
    def database_version
      return '8.0.0' unless defined?(ActiveRecord::Base)

      ActiveRecord::Base.connection.select_value('SELECT VERSION()')
    rescue StandardError => e
      raise "Failed to get MySQL version: #{e.message}"
    end

    # Checks if MySQL version is supported
    # @return [Boolean] true if version >= 8.0.0
    def version_supported?
      version_string = database_version.split('-').first
      Gem::Version.new(version_string) >= Gem::Version.new(MINIMUM_VERSION)
    rescue StandardError
      false
    end

    # Checks if encoding is utf8mb4
    # @return [Boolean] true if encoding is utf8mb4
    def encoding_compatible?
      return true unless defined?(ActiveRecord::Base)

      result = ActiveRecord::Base.connection.select_one(
        "SHOW VARIABLES LIKE 'character_set_database'"
      )
      result && result['Value'] == 'utf8mb4'
    rescue StandardError
      false
    end

    # Checks if required features are available
    # @return [Boolean] true if caching_sha2_password plugin is available
    def required_features_available?
      return true unless defined?(ActiveRecord::Base)

      plugins = ActiveRecord::Base.connection.select_values(
        "SELECT PLUGIN_NAME FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME = 'caching_sha2_password'"
      )
      plugins.include?('caching_sha2_password')
    rescue StandardError
      false
    end
  end

  # Custom error class for compatibility issues
  class CompatibilityError < StandardError; end
end
