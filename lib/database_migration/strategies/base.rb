# frozen_string_literal: true

module DatabaseMigration
  module Strategies
    # Base strategy interface for database migrations
    class Base
      attr_reader :config

      # Initializes the strategy
      # @param config [Hash] strategy configuration
      def initialize(config = {})
        @config = config
      end

      # Prepares for migration
      # @param source [DatabaseAdapter::Base] source adapter
      # @param target [DatabaseAdapter::Base] target adapter
      # @return [Hash] preparation result
      def prepare(source, target)
        raise NotImplementedError, "#{self.class} must implement prepare"
      end

      # Executes the migration
      # @param source [DatabaseAdapter::Base] source adapter
      # @param target [DatabaseAdapter::Base] target adapter
      # @return [Hash] migration result
      def migrate(source, target)
        raise NotImplementedError, "#{self.class} must implement migrate"
      end

      # Cleans up after migration
      # @return [Hash] cleanup result
      def cleanup
        # Default: no cleanup needed
        { status: 'no_cleanup_required' }
      end

      # Estimates migration duration in seconds
      # @return [Integer, nil] estimated duration or nil if unknown
      def estimated_duration
        nil
      end
    end
  end
end
