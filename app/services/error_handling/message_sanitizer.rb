# frozen_string_literal: true

module ErrorHandling
  # Sanitizes sensitive data from error messages and logs
  #
  # Removes credentials, tokens, and other sensitive information
  # before logging or displaying error messages.
  #
  # @example
  #   sanitizer = ErrorHandling::MessageSanitizer.new
  #   safe_message = sanitizer.sanitize(error.message)
  #   Rails.logger.error(safe_message)
  class MessageSanitizer
    # Patterns for detecting sensitive data
    SENSITIVE_PATTERNS = [
      /channel_(?:id|secret|token)[=:]\s*\S+/i,
      /authorization[=:]\s*\S+/i,
      /bearer\s+\S+/i
    ].freeze

    # Sanitize a message by removing sensitive data
    #
    # @param message [String] Original message
    # @return [String] Sanitized message
    def sanitize(message)
      sanitized = message.dup
      SENSITIVE_PATTERNS.each do |pattern|
        sanitized.gsub!(pattern, '[REDACTED]')
      end
      sanitized
    end

    # Format an exception with sanitized message
    #
    # @param exception [Exception] Exception to format
    # @param context [String] Context description
    # @param max_backtrace_lines [Integer] Maximum backtrace lines to include
    # @return [String] Formatted error message
    def format_error(exception, context, max_backtrace_lines: 5)
      <<~ERROR
        <#{context}>
        Exception: #{exception.class}
        Message: #{sanitize(exception.message)}
        Backtrace (first #{max_backtrace_lines} lines):
        #{exception.backtrace.first(max_backtrace_lines).join("\n")}
      ERROR
    end
  end
end
