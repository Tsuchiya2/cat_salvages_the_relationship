# frozen_string_literal: true

require_relative 'strategies/base'
require_relative 'strategies/postgresql_to_mysql8_strategy'

module DatabaseMigration
  # Factory for creating migration strategies
  class StrategyFactory
    # Map of source_to_target => Strategy class
    STRATEGY_MAP = {
      'postgresql_to_mysql2' => Strategies::PostgreSQLToMySQL8Strategy,
      'postgresql_to_mysql8' => Strategies::PostgreSQLToMySQL8Strategy,
      'pg_to_mysql2' => Strategies::PostgreSQLToMySQL8Strategy,
      'pg_to_mysql8' => Strategies::PostgreSQLToMySQL8Strategy
    }.freeze

    # Creates a migration strategy
    # @param source [String] source adapter name
    # @param target [String] target adapter name
    # @param config [Hash] strategy configuration
    # @return [DatabaseMigration::Strategies::Base] strategy instance
    def self.create(source:, target:, config: {})
      # Normalize adapter names
      normalized_source = normalize_adapter_name(source)
      normalized_target = normalize_adapter_name(target)

      strategy_key = "#{normalized_source}_to_#{normalized_target}"
      strategy_class = STRATEGY_MAP[strategy_key]

      unless strategy_class
        raise ArgumentError, "No migration strategy found for #{source} → #{target}. " \
                             "Available strategies: #{available_strategies.join(', ')}"
      end

      strategy_class.new(config)
    end

    # Returns list of available migration strategies
    # @return [Array<String>] list of available migration paths
    def self.available_strategies
      STRATEGY_MAP.keys.map do |key|
        key.gsub('_to_', ' → ').gsub('_', ' ')
      end
    end

    # Normalizes adapter name for strategy lookup
    # @param adapter_name [String] adapter name
    # @return [String] normalized adapter name
    def self.normalize_adapter_name(adapter_name)
      case adapter_name.to_s.downcase
      when 'mysql2', 'mysql8'
        'mysql2'
      when 'postgresql', 'pg'
        'postgresql'
      else
        adapter_name.to_s.downcase
      end
    end
    private_class_method :normalize_adapter_name
  end
end
