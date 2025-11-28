# frozen_string_literal: true

# Framework-agnostic authentication orchestration service
#
# This service coordinates authentication across multiple providers (password, OAuth, SAML, MFA).
# It routes authentication requests to the appropriate provider and logs all attempts
# with request correlation for observability.
#
# @example Password authentication
#   result = AuthenticationService.authenticate(
#     :password,
#     email: 'user@example.com',
#     password: 'secret123',
#     ip_address: '192.168.1.1'
#   )
#
#   if result.success?
#     session[:user_id] = result.user.id
#   else
#     flash[:error] = result.reason
#   end
#
# @example Future OAuth authentication
#   result = AuthenticationService.authenticate(
#     :oauth,
#     provider: 'google',
#     token: 'oauth_token_here',
#     ip_address: request.remote_ip
#   )
#
# @see Authentication::Provider for provider interface
# @see AuthResult for authentication result structure
class AuthenticationService
  class << self
    # Authenticate user with specified provider
    #
    # Routes authentication request to the appropriate provider based on provider_type.
    # Logs authentication attempt with request correlation for observability.
    #
    # @param provider_type [Symbol] Authentication provider type
    #   (:password, :oauth, :saml, :mfa, etc.)
    # @param ip_address [String, nil] IP address of authentication attempt (optional)
    # @param credentials [Hash] Provider-specific credentials
    #   For :password provider:
    #     - :email [String] User email address
    #     - :password [String] User password
    #   For :oauth provider (future):
    #     - :provider [String] OAuth provider name (google, github, etc.)
    #     - :token [String] OAuth token
    #
    # @return [AuthResult] Authentication result (success, failed, or pending_mfa)
    #
    # @raise [ArgumentError] if provider_type is unknown/unsupported
    #
    # @example Successful authentication
    #   result = AuthenticationService.authenticate(:password, email: 'user@example.com', password: 'secret')
    #   result.success? # => true
    #   result.user # => User instance
    #
    # @example Failed authentication
    #   result = AuthenticationService.authenticate(:password, email: 'user@example.com', password: 'wrong')
    #   result.failed? # => true
    #   result.reason # => 'invalid_password'
    #
    # @example Unknown provider
    #   AuthenticationService.authenticate(:unknown_provider)
    #   # => raises ArgumentError: Unknown provider type: unknown_provider
    def authenticate(provider_type, ip_address: nil, **credentials)
      start_time = Time.current

      provider = provider_for(provider_type)
      result = provider.authenticate(**credentials)

      # Record metrics
      record_metrics(provider_type, result, start_time)

      # Log authentication attempt
      log_authentication_attempt(provider_type, result, ip_address)

      result
    end

    private

    # Get provider instance for given type
    #
    # @param type [Symbol] Provider type (:password, :oauth, :saml, :mfa)
    # @return [Authentication::Provider] Provider instance
    # @raise [ArgumentError] if provider type is unknown
    def provider_for(type)
      case type
      when :password
        Authentication::PasswordProvider.new
      # Future providers can be added here:
      # when :oauth
      #   Authentication::OAuthProvider.new
      # when :saml
      #   Authentication::SamlProvider.new
      # when :mfa
      #   Authentication::MfaProvider.new
      else
        raise ArgumentError, "Unknown provider type: #{type}"
      end
    end

    # Record authentication metrics to Prometheus
    #
    # Records authentication attempts, duration, failures, and locked accounts
    # to Prometheus metrics for monitoring and alerting.
    #
    # @param provider_type [Symbol] Authentication provider used
    # @param result [AuthResult] Authentication result
    # @param start_time [Time] Authentication start time
    # @return [void]
    def record_metrics(provider_type, result, start_time)
      # Record total attempts
      AUTH_ATTEMPTS_TOTAL.increment(labels: { provider: provider_type, result: result.status })

      # Record duration
      duration = Time.current - start_time
      AUTH_DURATION.observe(duration, labels: { provider: provider_type })

      # Record failures with reason
      if result.failed?
        AUTH_FAILURES_TOTAL.increment(labels: { provider: provider_type, reason: result.reason })

        # Track locked accounts specifically
        AUTH_LOCKED_ACCOUNTS_TOTAL.increment(labels: { provider: provider_type }) if result.reason == :account_locked
      end
    rescue StandardError => e
      # Don't fail authentication if metrics recording fails
      Rails.logger.error("Failed to record authentication metrics: #{e.message}")
    end

    # Log authentication attempt with request correlation
    #
    # Structured logging format compatible with observability tools (Prometheus, Datadog, etc.)
    # Includes request_id for correlation across distributed traces.
    #
    # @param provider_type [Symbol] Authentication provider used
    # @param result [AuthResult] Authentication result
    # @param ip_address [String, nil] IP address of authentication attempt
    # @return [void]
    def log_authentication_attempt(provider_type, result, ip_address)
      Rails.logger.info(
        event: 'authentication_attempt',
        provider: provider_type,
        result: result.status,
        reason: result.reason,
        ip: ip_address,
        request_id: RequestStore.store[:request_id],
        timestamp: Time.current.iso8601
      )
    end
  end
end
