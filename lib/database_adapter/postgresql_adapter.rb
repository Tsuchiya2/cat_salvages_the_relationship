# frozen_string_literal: true

require_relative 'base'

module DatabaseAdapter
  # PostgreSQL adapter implementation
  class PostgreSQLAdapter < Base
    MINIMUM_VERSION = '12.0'

    # Returns the adapter name
    # @return [String] 'postgresql'
    def adapter_name
      'postgresql'
    end

    # Migrates data to target adapter
    # @param source_adapter [DatabaseAdapter::Base] source adapter (self)
    # @param options [Hash] migration options
    # @return [Hash] migration result
    def migrate_from(_source_adapter, _options = {})
      raise "PostgreSQL cannot be used as a migration target from itself"
    end

    # Verifies PostgreSQL compatibility
    # @return [Hash] compatibility check results
    def verify_compatibility
      checks = {
        version_check: version_supported?,
        encoding_check: encoding_compatible?
      }

      unless checks.values.all?
        raise CompatibilityError, "Compatibility checks failed: #{checks}"
      end

      checks
    end

    # Returns connection parameters for PostgreSQL
    # @return [Hash] connection parameters
    def connection_params
      {
        adapter: 'postgresql',
        encoding: 'unicode',
        pool: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
        timeout: 5000
      }.merge(@config)
    end

    protected

    # Returns the PostgreSQL version
    # @return [String] PostgreSQL version string
    def database_version
      return '12.0' unless defined?(ActiveRecord::Base)

      version_string = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
      # Extract version number from string like "PostgreSQL 14.5 on x86_64..."
      version_string.match(/PostgreSQL (\d+\.\d+)/)[1]
    rescue StandardError => e
      raise "Failed to get PostgreSQL version: #{e.message}"
    end

    # Checks if PostgreSQL version is supported
    # @return [Boolean] true if version >= 12.0
    def version_supported?
      Gem::Version.new(database_version) >= Gem::Version.new(MINIMUM_VERSION)
    rescue StandardError
      false
    end

    # Checks if encoding is unicode/UTF8
    # @return [Boolean] true if encoding is compatible
    def encoding_compatible?
      return true unless defined?(ActiveRecord::Base)

      encoding = ActiveRecord::Base.connection.select_value(
        "SHOW server_encoding"
      )
      %w[UTF8 UNICODE].include?(encoding)
    rescue StandardError
      false
    end
  end
end
