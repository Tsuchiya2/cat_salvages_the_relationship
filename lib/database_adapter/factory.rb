# frozen_string_literal: true

require_relative 'mysql8_adapter'
require_relative 'postgresql_adapter'

module DatabaseAdapter
  # Factory for creating database adapters
  class Factory
    # Creates a database adapter instance
    # @param adapter_type [String, Symbol] adapter type ('mysql2', 'mysql8', 'postgresql', 'pg')
    # @param config [Hash] adapter configuration
    # @return [DatabaseAdapter::Base] adapter instance
    def self.create(adapter_type, config = {})
      case adapter_type.to_s.downcase
      when 'mysql2', 'mysql8'
        MySQL8Adapter.new(config)
      when 'postgresql', 'pg'
        PostgreSQLAdapter.new(config)
      else
        raise ArgumentError, "Unsupported adapter type: #{adapter_type}"
      end
    end

    # Creates adapter for current database connection
    # @return [DatabaseAdapter::Base] current adapter instance
    def self.current_adapter
      return nil unless defined?(ActiveRecord::Base)

      adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
      create(adapter_name)
    rescue StandardError => e
      raise "Failed to create current adapter: #{e.message}"
    end
  end
end
