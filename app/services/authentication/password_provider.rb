# frozen_string_literal: true

module Authentication
  # Password authentication provider
  #
  # This provider handles traditional email/password authentication.
  # It integrates with the BruteForceProtection concern to prevent
  # brute force attacks by locking accounts after too many failed attempts.
  #
  # Features:
  # - Email/password authentication
  # - Account lock detection
  # - Failed login tracking
  # - Automatic lock after exceeding retry limit
  # - Reset failed logins on success
  #
  # @example Authenticate with email and password
  #   provider = Authentication::PasswordProvider.new
  #   result = provider.authenticate(email: 'user@example.com', password: 'secret123')
  #   if result.success?
  #     session[:operator_id] = result.user.id
  #   else
  #     flash[:error] = result.reason
  #   end
  #
  # @see Authentication::Provider
  # @see AuthResult
  # @see BruteForceProtection
  class PasswordProvider < Provider
    # Authenticate operator with email and password
    #
    # This method performs the following checks in order:
    # 1. Find operator by email (case-insensitive)
    # 2. Check if account is locked
    # 3. Verify password using has_secure_password
    # 4. Handle success/failure with brute force protection
    #
    # @param email [String] Operator's email address
    # @param password [String] Operator's password
    # @return [AuthResult] Authentication result
    #   - Success: Returns AuthResult with user and resets failed login counter
    #   - Failed (user not found): Returns AuthResult with :user_not_found reason
    #   - Failed (account locked): Returns AuthResult with :account_locked reason and user
    #   - Failed (invalid password): Returns AuthResult with :invalid_credentials reason,
    #                                increments failed login counter, and may lock account
    #
    # @example Successful authentication
    #   result = provider.authenticate(email: 'user@example.com', password: 'correct')
    #   result.success? # => true
    #   result.user # => Operator instance
    #
    # @example Failed authentication - user not found
    #   result = provider.authenticate(email: 'unknown@example.com', password: 'any')
    #   result.failed? # => true
    #   result.reason # => :user_not_found
    #
    # @example Failed authentication - account locked
    #   result = provider.authenticate(email: 'locked@example.com', password: 'any')
    #   result.failed? # => true
    #   result.reason # => :account_locked
    #
    # @example Failed authentication - invalid password
    #   result = provider.authenticate(email: 'user@example.com', password: 'wrong')
    #   result.failed? # => true
    #   result.reason # => :invalid_credentials
    def authenticate(email:, password:)
      operator = Operator.find_by(email: email.to_s.downcase.strip)
      return AuthResult.failed(:user_not_found) unless operator

      return AuthResult.failed(:account_locked, user: operator) if operator.locked?

      if operator.authenticate(password)
        operator.reset_failed_logins!
        AuthResult.success(user: operator)
      else
        operator.increment_failed_logins!
        AuthResult.failed(:invalid_credentials, user: operator)
      end
    end

    # Check if this provider supports password authentication
    #
    # @param credential_type [Symbol] Type of credentials to check
    # @return [Boolean] true if credential_type is :password
    #
    # @example
    #   provider = Authentication::PasswordProvider.new
    #   provider.supports?(:password) # => true
    #   provider.supports?(:oauth)    # => false
    def supports?(credential_type)
      credential_type == :password
    end
  end
end
