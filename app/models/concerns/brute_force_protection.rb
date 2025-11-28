# frozen_string_literal: true

# BruteForceProtection Concern
#
# Provides parameterized brute force protection for authentication models.
# This concern can be reused across multiple models (e.g., Operator, Admin, User).
#
# Configuration:
#   - lock_retry_limit: Number of failed login attempts before locking (default: 5)
#   - lock_duration: Duration of account lock in seconds (default: 45 minutes)
#   - lock_notifier: Optional callback to notify when account is locked
#
# Required database fields:
#   - failed_logins_count: integer
#   - lock_expires_at: datetime
#   - unlock_token: string
#
# Usage:
#   class Operator < ApplicationRecord
#     include BruteForceProtection
#
#     # Optional: customize configuration
#     self.lock_retry_limit = ENV.fetch('OPERATOR_LOCK_RETRY_LIMIT', 5).to_i
#     self.lock_duration = ENV.fetch('OPERATOR_LOCK_DURATION', 45).to_i.minutes
#     self.lock_notifier = ->(record, ip) { record.mail_notice(ip) }
#   end
#
module BruteForceProtection
  extend ActiveSupport::Concern

  included do
    # Class attributes with defaults
    # These can be overridden in the including model
    class_attribute :lock_retry_limit, default: ENV.fetch('LOCK_RETRY_LIMIT', 5).to_i
    class_attribute :lock_duration, default: ENV.fetch('LOCK_DURATION', 45).to_i.minutes
    class_attribute :lock_notifier, default: nil
  end

  # Increments the failed login counter and locks the account if limit is reached
  #
  # @return [Boolean] true if account was locked, false otherwise
  def increment_failed_logins!
    increment!(:failed_logins_count) # rubocop:disable Rails/SkipsModelValidations
    lock_account! if failed_logins_count >= lock_retry_limit
  end

  # Resets the failed login counter and clears the lock
  #
  # @return [Boolean] true if update succeeded
  def reset_failed_logins!
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(
      failed_logins_count: 0,
      lock_expires_at: nil,
      updated_at: Time.current
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Locks the account by setting expiration time and generating unlock token
  #
  # @return [Boolean] true if update succeeded
  def lock_account!
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(
      lock_expires_at: Time.current + lock_duration,
      unlock_token: SecureRandom.urlsafe_base64(32),
      updated_at: Time.current
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Unlocks the account and resets all protection fields
  #
  # @return [Boolean] true if update succeeded
  def unlock_account!
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(
      lock_expires_at: nil,
      unlock_token: nil,
      failed_logins_count: 0,
      updated_at: Time.current
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Checks if the account is currently locked
  #
  # @return [Boolean] true if locked, false otherwise
  def locked?
    lock_expires_at.present? && lock_expires_at > Time.current
  end

  # Sends notification email when account is locked (if notifier is configured)
  #
  # @param ip_address [String] the IP address that triggered the lock
  # @return [void]
  def mail_notice(ip_address)
    lock_notifier&.call(self, ip_address)
  end
end
