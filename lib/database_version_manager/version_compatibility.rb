# frozen_string_literal: true

require 'yaml'

module DatabaseVersionManager
  # Manages database version compatibility checking
  class VersionCompatibility
    REQUIREMENTS_FILE = 'config/database_version_requirements.yml'

    class << self
      # Returns supported versions for an adapter
      # @param adapter [String, Symbol] adapter name
      # @return [Hash] version requirements
      def supported_versions(adapter:)
        requirements = load_requirements
        adapter_key = normalize_adapter_name(adapter)
        requirements[adapter_key] || {}
      end

      # Verifies current database version meets requirements
      # @param adapter [String, Symbol, nil] adapter name (defaults to current)
      # @raise [DatabaseVersionError] if version is not supported
      # @return [Boolean] true if version is supported
      def verify_version!(adapter: nil)
        adapter ||= current_adapter_name
        version = current_version(adapter)

        requirements = supported_versions(adapter: adapter)

        unless version_compatible?(version, requirements)
          raise DatabaseVersionError,
                "Unsupported database version: #{version}. " \
                "Minimum required: #{requirements['minimum_version']}, " \
                "Recommended: #{requirements['recommended_version']}"
        end

        if version_deprecated?(version, requirements)
          warn_deprecated_version(adapter, version, requirements)
        end

        true
      end

      # Returns current database version
      # @param adapter [String, Symbol] adapter name
      # @return [String] version string
      def current_version(adapter)
        adapter_sym = normalize_adapter_name(adapter).to_sym

        case adapter_sym
        when :mysql2
          get_mysql_version
        when :postgresql
          get_postgresql_version
        else
          raise ArgumentError, "Unknown adapter: #{adapter}"
        end
      end

      # Returns upgrade path from one version to another
      # @param from [String] source version
      # @param to [String] target version
      # @return [Hash] upgrade path information
      def upgrade_path(from:, to:)
        {
          from_version: from,
          to_version: to,
          steps: generate_upgrade_steps(from, to),
          estimated_downtime: estimate_upgrade_downtime(from, to),
          breaking_changes: check_breaking_changes(from, to)
        }
      end

      private

      # Loads version requirements from YAML file
      # @return [Hash] requirements hash
      def load_requirements
        file_path = Rails.root.join(REQUIREMENTS_FILE)

        unless File.exist?(file_path)
          Rails.logger.warn "Version requirements file not found: #{REQUIREMENTS_FILE}"
          return {}
        end

        YAML.load_file(file_path)
      rescue StandardError => e
        Rails.logger.error "Failed to load version requirements: #{e.message}"
        {}
      end

      # Checks if version is compatible with requirements
      # @param version [String] version to check
      # @param requirements [Hash] version requirements
      # @return [Boolean] true if compatible
      def version_compatible?(version, requirements)
        return true if requirements.empty?
        return true unless requirements['minimum_version']

        min_version = Gem::Version.new(requirements['minimum_version'])
        current = Gem::Version.new(version)

        current >= min_version
      rescue ArgumentError => e
        Rails.logger.error "Invalid version comparison: #{e.message}"
        false
      end

      # Checks if version is deprecated
      # @param version [String] version to check
      # @param requirements [Hash] version requirements
      # @return [Boolean] true if deprecated
      def version_deprecated?(version, requirements)
        return false unless requirements['deprecated_below']

        deprecated_version = Gem::Version.new(requirements['deprecated_below'])
        current = Gem::Version.new(version)

        current < deprecated_version
      rescue ArgumentError
        false
      end

      # Gets MySQL version
      # @return [String] MySQL version
      def get_mysql_version
        return '8.0.0' unless defined?(ActiveRecord::Base)

        version_string = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
        version_string.split('-').first
      rescue StandardError => e
        raise DatabaseVersionError, "Failed to get MySQL version: #{e.message}"
      end

      # Gets PostgreSQL version
      # @return [String] PostgreSQL version
      def get_postgresql_version
        return '12.0' unless defined?(ActiveRecord::Base)

        version_string = ActiveRecord::Base.connection.select_value('SHOW server_version')
        version_string.split.first
      rescue StandardError => e
        raise DatabaseVersionError, "Failed to get PostgreSQL version: #{e.message}"
      end

      # Gets current adapter name from ActiveRecord
      # @return [String] adapter name
      def current_adapter_name
        return 'mysql2' unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.connection.adapter_name.downcase
      rescue StandardError
        'mysql2'
      end

      # Normalizes adapter name
      # @param adapter [String, Symbol] adapter name
      # @return [String] normalized adapter name
      def normalize_adapter_name(adapter)
        case adapter.to_s.downcase
        when 'mysql', 'mysql8'
          'mysql2'
        when 'pg'
          'postgresql'
        else
          adapter.to_s.downcase
        end
      end

      # Warns about deprecated version
      # @param adapter [String] adapter name
      # @param version [String] current version
      # @param requirements [Hash] version requirements
      def warn_deprecated_version(adapter, version, requirements)
        Rails.logger.warn(
          "Database version #{adapter} #{version} is deprecated. " \
          "Please upgrade to #{requirements['recommended_version']} or higher."
        )
      end

      # Generates upgrade steps (placeholder)
      # @param _from [String] source version
      # @param _to [String] target version
      # @return [Array<String>] upgrade steps
      def generate_upgrade_steps(_from, _to)
        [
          'Create backup of current database',
          'Review breaking changes and compatibility issues',
          'Test application on new version in staging environment',
          'Schedule maintenance window',
          'Perform upgrade during maintenance window',
          'Verify application functionality post-upgrade'
        ]
      end

      # Estimates upgrade downtime (placeholder)
      # @param _from [String] source version
      # @param _to [String] target version
      # @return [Integer] estimated downtime in minutes
      def estimate_upgrade_downtime(_from, _to)
        30 # Default 30 minutes
      end

      # Checks for breaking changes (placeholder)
      # @param _from [String] source version
      # @param _to [String] target version
      # @return [Array<String>] breaking changes
      def check_breaking_changes(_from, _to)
        []
      end
    end
  end

  # Custom error class for version-related errors
  class DatabaseVersionError < StandardError; end
end
