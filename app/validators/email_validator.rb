# frozen_string_literal: true

# EmailValidator provides email validation and normalization functionality
#
# This validator can be used in two ways:
#
# 1. As an ActiveModel validator:
#    validates :email, email: true
#
# 2. As a standalone utility:
#    EmailValidator.valid_format?('user@example.com')
#    EmailValidator.normalize('USER@EXAMPLE.COM')
#
# The email format follows the pattern: [a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+
#
class EmailValidator < ActiveModel::EachValidator
  # Default email format regex
  # Matches: lowercase letters, numbers, underscores, and hyphens
  # Format: local@domain.tld
  DEFAULT_FORMAT = /\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/

  # Validates each attribute with email format
  #
  # @param record [ActiveModel::Base] The record being validated
  # @param attribute [Symbol] The attribute name to validate
  # @param value [String] The email value
  def validate_each(record, attribute, value)
    return if value.blank?

    format = options[:format] || DEFAULT_FORMAT

    return if value.match?(format)

    record.errors.add(attribute, options[:message] || :invalid)
  end

  class << self
    # Checks if the email has valid format
    #
    # @param email [String] The email address to validate
    # @param format [Regexp] Custom regex pattern (optional)
    # @return [Boolean] true if email matches the format
    #
    # @example
    #   EmailValidator.valid_format?('user@example.com')
    #   # => true
    #
    #   EmailValidator.valid_format?('invalid@')
    #   # => false
    #
    #   EmailValidator.valid_format?('user@example.com', /custom_pattern/)
    #   # => true or false based on custom pattern
    def valid_format?(email, format = DEFAULT_FORMAT)
      return false if email.blank?

      email.to_s.match?(format)
    end

    # Normalizes email address to lowercase and removes whitespace
    #
    # @param email [String] The email address to normalize
    # @return [String] Normalized email address
    #
    # @example
    #   EmailValidator.normalize('  USER@EXAMPLE.COM  ')
    #   # => 'user@example.com'
    #
    #   EmailValidator.normalize(nil)
    #   # => ''
    def normalize(email)
      email.to_s.downcase.strip
    end

    # Sanitizes email by normalizing and validating
    # Returns normalized email if valid, otherwise returns nil
    #
    # @param email [String] The email address to sanitize
    # @param format [Regexp] Custom regex pattern (optional)
    # @return [String, nil] Sanitized email or nil if invalid
    #
    # @example
    #   EmailValidator.sanitize('  USER@EXAMPLE.COM  ')
    #   # => 'user@example.com'
    #
    #   EmailValidator.sanitize('invalid@')
    #   # => nil
    def sanitize(email, format = DEFAULT_FORMAT)
      normalized = normalize(email)
      valid_format?(normalized, format) ? normalized : nil
    end
  end
end
