# frozen_string_literal: true

module Webhooks
  # Validates HMAC signatures for webhook requests
  #
  # Provides secure signature validation using constant-time comparison
  # to prevent timing attacks.
  #
  # @example
  #   validator = Webhooks::SignatureValidator.new(ENV['WEBHOOK_SECRET'])
  #   if validator.valid?(request.body.read, request.headers['X-Signature'])
  #     # Process webhook
  #   else
  #     # Reject request
  #   end
  class SignatureValidator
    # Initialize validator with secret key
    #
    # @param secret [String] Secret key for HMAC signature generation
    def initialize(secret)
      @secret = secret
    end

    # Validate webhook signature
    #
    # Uses constant-time comparison to prevent timing attacks
    #
    # @param body [String] Request body
    # @param signature [String] Signature from webhook provider
    # @return [Boolean] true if signature is valid
    def valid?(body, signature)
      return false if signature.blank?

      expected = compute_signature(body)
      secure_compare(expected, signature)
    end

    private

    # Compute HMAC-SHA256 signature
    #
    # @param body [String] Request body
    # @return [String] Base64-encoded signature
    def compute_signature(body)
      Base64.strict_encode64(
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), @secret, body)
      )
    end

    # Constant-time string comparison
    #
    # @param expected [String] Expected signature
    # @param actual [String] Actual signature
    # @return [Boolean] true if strings are equal
    def secure_compare(expected, actual)
      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end
  end
end
