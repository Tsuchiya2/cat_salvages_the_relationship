# frozen_string_literal: true

module Authentication
  # Abstract base class for authentication providers
  #
  # This class defines the interface that all authentication providers must implement.
  # It supports various authentication mechanisms including:
  # - Password-based authentication
  # - OAuth 2.0 providers (Google, GitHub, etc.)
  # - SAML authentication
  # - Multi-Factor Authentication (MFA)
  #
  # @abstract Subclasses must implement {#authenticate} and {#supports?}
  #
  # @example Implementing a custom provider
  #   class MyProvider < Authentication::Provider
  #     def authenticate(credentials)
  #       # Implementation logic
  #       if valid_credentials?(credentials)
  #         AuthResult.success(user: user)
  #       else
  #         AuthResult.failed('invalid_credentials')
  #       end
  #     end
  #
  #     def supports?(credential_type)
  #       credential_type == :my_auth_type
  #     end
  #   end
  #
  # @see AuthResult for authentication result structure
  class Provider
    # Authenticate user with provided credentials
    #
    # This method must be implemented by all authentication provider subclasses.
    # It should validate the credentials and return an AuthResult indicating
    # success, failure, or pending MFA verification.
    #
    # @abstract Subclass must implement this method
    # @param credentials [Hash] Authentication credentials (format varies by provider)
    # @option credentials [String] :email User email address
    # @option credentials [String] :password User password
    # @option credentials [String] :token OAuth/SAML token
    # @option credentials [String] :mfa_code Multi-factor authentication code
    # @return [AuthResult] Result of authentication attempt
    # @raise [NotImplementedError] if not overridden by subclass
    #
    # @example Password authentication credentials
    #   provider.authenticate(email: 'user@example.com', password: 'secret123')
    #
    # @example OAuth authentication credentials
    #   provider.authenticate(token: 'oauth_token_here', provider: 'google')
    def authenticate(credentials)
      raise NotImplementedError, "#{self.class} must implement #authenticate"
    end

    # Check if this provider supports a given credential type
    #
    # This method must be implemented by all authentication provider subclasses.
    # It determines whether the provider can handle a specific type of credentials.
    #
    # @abstract Subclass must implement this method
    # @param credential_type [Symbol] Type of credentials
    #   (:password, :oauth, :saml, :mfa, :totp, etc.)
    # @return [Boolean] true if provider supports this credential type
    # @raise [NotImplementedError] if not overridden by subclass
    #
    # @example Checking credential support
    #   provider.supports?(:password) # => true or false
    #   provider.supports?(:oauth)    # => true or false
    def supports?(credential_type)
      raise NotImplementedError, "#{self.class} must implement #supports?"
    end
  end
end
