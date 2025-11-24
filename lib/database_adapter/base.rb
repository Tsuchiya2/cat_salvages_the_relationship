# frozen_string_literal: true

module DatabaseAdapter
  # Base adapter interface for database operations
  # Provides abstraction layer for different database systems
  class Base
    attr_reader :config

    def initialize(config = {})
      @config = config
    end

    # Returns the adapter name (e.g., 'mysql2', 'postgresql')
    # @return [String] adapter name
    def adapter_name
      raise NotImplementedError, "#{self.class} must implement adapter_name"
    end

    # Migrates data from source adapter to this adapter
    # @param source_adapter [DatabaseAdapter::Base] source database adapter
    # @param options [Hash] migration options
    # @return [Hash] migration result
    def migrate_from(source_adapter, options = {})
      raise NotImplementedError, "#{self.class} must implement migrate_from"
    end

    # Verifies compatibility of this adapter
    # @return [Hash] compatibility check results
    def verify_compatibility
      raise NotImplementedError, "#{self.class} must implement verify_compatibility"
    end

    # Returns connection parameters for this adapter
    # @return [Hash] connection parameters
    def connection_params
      raise NotImplementedError, "#{self.class} must implement connection_params"
    end

    # Returns version information for this adapter
    # @return [Hash] version info including adapter, version, supported status
    def version_info
      {
        adapter: adapter_name,
        version: database_version,
        supported: version_supported?
      }
    end

    protected

    # Returns the database version string
    # @return [String] database version
    def database_version
      raise NotImplementedError, "#{self.class} must implement database_version"
    end

    # Checks if the current database version is supported
    # @return [Boolean] true if version is supported
    def version_supported?
      raise NotImplementedError, "#{self.class} must implement version_supported?"
    end
  end
end
