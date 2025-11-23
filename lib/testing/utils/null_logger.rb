# frozen_string_literal: true

module Testing
  module Utils
    # Null object pattern implementation for logger.
    #
    # Provides a no-op logger that can be used as a drop-in replacement for
    # Rails.logger or any standard Ruby logger. All methods accept any arguments
    # and do nothing (no-op), avoiding the need for Rails dependency.
    #
    # Used as default logger when no logger is injected into components.
    #
    # @example Basic usage
    #   logger = NullLogger.new
    #   logger.info('message') # Does nothing
    #   logger.debug('debug', key: 'value') # Does nothing
    #
    # @example As default logger
    #   def initialize(logger: NullLogger.new)
    #     @logger = logger
    #   end
    #
    # @since 1.0.0
    class NullLogger
      # Log debug message (no-op).
      #
      # @param args [Array] Any arguments (ignored)
      # @return [nil]
      def debug(*_args); end

      # Log info message (no-op).
      #
      # @param args [Array] Any arguments (ignored)
      # @return [nil]
      def info(*_args); end

      # Log warning message (no-op).
      #
      # @param args [Array] Any arguments (ignored)
      # @return [nil]
      def warn(*_args); end

      # Log error message (no-op).
      #
      # @param args [Array] Any arguments (ignored)
      # @return [nil]
      def error(*_args); end

      # Log fatal message (no-op).
      #
      # @param args [Array] Any arguments (ignored)
      # @return [nil]
      def fatal(*_args); end
    end
  end
end
