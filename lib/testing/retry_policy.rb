# frozen_string_literal: true

require_relative 'utils/null_logger'

module Testing
  # Configurable retry mechanism with exponential backoff.
  #
  # Retries transient failures (network errors, timeouts) while skipping
  # assertion failures. Framework-agnostic and works with RSpec, Minitest,
  # or standalone Ruby.
  #
  # @example Basic usage
  #   policy = RetryPolicy.new(
  #     max_attempts: 3,
  #     backoff_multiplier: 2,
  #     initial_delay: 2,
  #     logger: Rails.logger,
  #     retryable_errors: [Errno::ECONNREFUSED, Timeout::Error],
  #     non_retryable_errors: [RSpec::Expectations::ExpectationNotMetError]
  #   )
  #
  #   policy.execute do
  #     # Code that might fail transiently
  #     Net::HTTP.get(URI('http://localhost:3000'))
  #   end
  #
  # @example With custom error configuration
  #   policy = RetryPolicy.new(
  #     max_attempts: 5,
  #     retryable_errors: [Playwright::TimeoutError, Selenium::WebDriver::Error::WebDriverError]
  #   )
  #
  # @since 1.0.0
  class RetryPolicy
    # Default maximum retry attempts
    DEFAULT_MAX_ATTEMPTS = 3

    # Default backoff multiplier (exponential)
    DEFAULT_BACKOFF_MULTIPLIER = 2

    # Default initial delay in seconds
    DEFAULT_INITIAL_DELAY = 2

    # @return [Integer] Maximum retry attempts
    attr_reader :max_attempts

    # @return [Integer] Backoff multiplier for exponential backoff
    attr_reader :backoff_multiplier

    # @return [Integer] Initial delay in seconds
    attr_reader :initial_delay

    # @return [Logger] Logger instance
    attr_reader :logger

    # @return [Array<Class>] List of retryable error classes
    attr_reader :retryable_errors

    # @return [Array<Class>] List of non-retryable error classes
    attr_reader :non_retryable_errors

    # Initialize retry policy.
    #
    # @param max_attempts [Integer] Maximum retry attempts (default: 3)
    # @param backoff_multiplier [Integer] Exponential backoff multiplier (default: 2)
    # @param initial_delay [Integer] Initial delay in seconds (default: 2)
    # @param logger [Logger] Logger for retry attempts (default: NullLogger)
    # @param error_handling [Hash] Error handling configuration
    # @option error_handling [Array<Class>] :retryable Retryable error classes
    # @option error_handling [Array<Class>] :non_retryable Non-retryable error classes
    def initialize(
      max_attempts: DEFAULT_MAX_ATTEMPTS,
      backoff_multiplier: DEFAULT_BACKOFF_MULTIPLIER,
      initial_delay: DEFAULT_INITIAL_DELAY,
      logger: Utils::NullLogger.new,
      error_handling: {}
    )
      raise ArgumentError, 'max_attempts must be greater than 0' unless max_attempts.positive?
      raise ArgumentError, 'backoff_multiplier must be greater than 0' unless backoff_multiplier.positive?
      raise ArgumentError, 'initial_delay must be greater than or equal to 0' unless initial_delay >= 0

      @max_attempts = max_attempts
      @backoff_multiplier = backoff_multiplier
      @initial_delay = initial_delay
      @logger = logger
      retryable = error_handling.fetch(:retryable, [StandardError])
      @retryable_errors = retryable.empty? ? [StandardError] : retryable
      @non_retryable_errors = error_handling.fetch(:non_retryable, []) + default_non_retryable_errors
    end

    # Execute block with retry logic.
    #
    # Retries transient failures up to max_attempts with exponential backoff.
    # Does not retry assertion failures or non-retryable errors.
    #
    # @yield Block to execute with retry logic
    # @return [Object] Return value of block
    # @raise [StandardError] Re-raises error after max attempts or if non-retryable
    #
    # @example
    #   result = policy.execute do
    #     # Code that might fail
    #   end
    def execute
      attempt = 0

      begin
        yield
      rescue StandardError => e
        raise unless retryable_error?(e) && attempt < max_attempts - 1

        delay = calculate_delay(attempt)
        log_retry_attempt(attempt + 1, e, delay)

        sleep(delay)
        attempt += 1
        retry
      end
    end

    private

    # Calculate exponential backoff delay.
    #
    # @param attempt [Integer] Current attempt number (0-indexed)
    # @return [Integer] Delay in seconds
    #
    # @example
    #   calculate_delay(0) #=> 2
    #   calculate_delay(1) #=> 4
    #   calculate_delay(2) #=> 8
    def calculate_delay(attempt)
      initial_delay * (backoff_multiplier**attempt)
    end

    # Check if error is retryable.
    #
    # @param error [Exception] Error to check
    # @return [Boolean] true if retryable, false otherwise
    def retryable_error?(error)
      # Never retry non-retryable errors
      return false if non_retryable_errors.any? { |klass| error.is_a?(klass) }

      # Only retry if error matches retryable errors
      retryable_errors.any? { |klass| error.is_a?(klass) }
    end

    # Log retry attempt with structured output.
    #
    # @param attempt [Integer] Current attempt number
    # @param error [Exception] Error that triggered retry
    # @param delay [Integer] Delay before next attempt
    # @return [void]
    def log_retry_attempt(attempt, error, delay)
      logger.warn(
        "Retry attempt #{attempt}/#{max_attempts} | " \
        "error=#{error.class.name} | " \
        "message=#{error.message} | " \
        "delay=#{delay}s"
      )
    end

    # Default non-retryable error classes.
    #
    # These errors indicate test failures, not transient issues.
    #
    # @return [Array<Class>] List of non-retryable error classes
    def default_non_retryable_errors
      errors = []

      # RSpec assertion errors (if RSpec is loaded)
      errors << RSpec::Expectations::ExpectationNotMetError if defined?(RSpec::Expectations::ExpectationNotMetError)

      # Minitest assertion errors (if Minitest is loaded)
      errors << Minitest::Assertion if defined?(Minitest::Assertion)

      errors
    end
  end
end
