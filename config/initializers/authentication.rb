# frozen_string_literal: true

# Authentication Configuration
# All settings can be overridden via environment variables
#
# This configuration centralizes authentication-related settings and provides
# a single source of truth for security parameters. All values have sensible
# defaults that match the current Sorcery configuration.
#
# Environment Variables:
# - AUTH_LOGIN_RETRY_LIMIT: Maximum number of failed login attempts before locking (default: 5)
# - AUTH_LOGIN_LOCK_DURATION: Duration in minutes to lock account after failed attempts (default: 45)
# - AUTH_BCRYPT_COST: bcrypt cost factor for password hashing (default: 4 in test, 12 in production)
# - AUTH_PASSWORD_MIN_LENGTH: Minimum password length requirement (default: 8)
# - AUTH_SESSION_TIMEOUT: Session timeout in minutes (default: 30)
# - AUTH_OAUTH_ENABLED: Enable OAuth authentication (default: false)
# - AUTH_MFA_ENABLED: Enable multi-factor authentication (default: false)

Rails.application.config.authentication = {
  # Brute Force Protection
  # Controls how many failed login attempts are allowed before locking the account
  # and how long the account remains locked.
  login_retry_limit: ENV.fetch('AUTH_LOGIN_RETRY_LIMIT', 5).to_i,
  login_lock_duration: ENV.fetch('AUTH_LOGIN_LOCK_DURATION', 45).to_i.minutes,

  # Password Settings
  # bcrypt cost factor: higher values increase security but slow down authentication
  # Cost of 4 is fast for tests, cost of 12 is secure for production
  bcrypt_cost: ENV.fetch('AUTH_BCRYPT_COST', Rails.env.test? ? 4 : 12).to_i,
  password_min_length: ENV.fetch('AUTH_PASSWORD_MIN_LENGTH', 8).to_i,

  # Session Settings
  # Timeout for inactive sessions
  session_timeout: ENV.fetch('AUTH_SESSION_TIMEOUT', 30).to_i.minutes,

  # Feature Flags
  # Enable/disable optional authentication features
  oauth_enabled: ENV.fetch('AUTH_OAUTH_ENABLED', 'false') == 'true',
  mfa_enabled: ENV.fetch('AUTH_MFA_ENABLED', 'false') == 'true'
}

# Log configuration in non-production environments for debugging
unless Rails.env.production?
  Rails.logger.debug '=' * 80
  Rails.logger.debug 'Authentication Configuration:'
  Rails.logger.debug '=' * 80
  Rails.application.config.authentication.each do |key, value|
    Rails.logger.debug "  #{key}: #{value}"
  end
  Rails.logger.debug '=' * 80
end
