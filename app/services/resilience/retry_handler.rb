# frozen_string_literal: true

module Resilience
  # Handles retries with exponential backoff
  #
  # Provides resilient error handling for transient failures
  # with configurable retry attempts and backoff strategy.
  #
  # @example
  #   handler = Resilience::RetryHandler.new(max_attempts: 3)
  #   handler.call do
  #     # Potentially failing operation
  #     api_client.fetch_data
  #   end
  class RetryHandler
    # Default retryable error classes
    DEFAULT_RETRYABLE_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED
    ].freeze

    # Initialize retry handler
    #
    # @param max_attempts [Integer] Maximum retry attempts
    # @param backoff_factor [Integer] Exponential backoff base
    # @param retryable_errors [Array<Class>] Error classes to retry
    def initialize(max_attempts: 3, backoff_factor: 2, retryable_errors: DEFAULT_RETRYABLE_ERRORS)
      @max_attempts = max_attempts
      @backoff_factor = backoff_factor
      @retryable_errors = retryable_errors
    end

    # Execute block with retry logic
    #
    # Retries block on retryable errors with exponential backoff.
    # Re-raises error after max attempts exceeded.
    #
    # @yield Block to execute
    # @return Result of block execution
    # @raise Original error if max attempts exceeded
    def call
      attempts = 0

      begin
        attempts += 1
        yield
      rescue StandardError => e
        raise unless attempts < @max_attempts && retryable?(e)

        sleep(@backoff_factor**attempts)
        retry
      end
    end

    private

    # Check if error is retryable
    #
    # @param error [Exception] Error to check
    # @return [Boolean] true if error is retryable
    def retryable?(error)
      @retryable_errors.any? { |klass| error.is_a?(klass) } ||
        (error.respond_to?(:response) && error.response&.code == '500')
    end
  end
end
