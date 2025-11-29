# frozen_string_literal: true

# Value object representing authentication operation outcomes
#
# This class encapsulates the result of authentication attempts, supporting:
# - Successful authentication with user
# - Failed authentication with reason
# - Pending MFA (Multi-Factor Authentication) status
#
# @example Successful authentication
#   result = AuthResult.success(user: user)
#   result.success? # => true
#   result.user # => User instance
#
# @example Failed authentication
#   result = AuthResult.failed('invalid_password', user: user)
#   result.failed? # => true
#   result.reason # => 'invalid_password'
#
# @example Pending MFA
#   result = AuthResult.pending_mfa(user: user)
#   result.pending_mfa? # => true
class AuthResult
  # @return [Symbol] Authentication status (:success, :failed, :pending_mfa)
  attr_reader :status

  # @return [User, nil] Authenticated user (nil if not available)
  attr_reader :user

  # @return [String, nil] Failure reason (only for :failed status)
  attr_reader :reason

  # Create a successful authentication result
  #
  # @param user [User] The authenticated user
  # @return [AuthResult] Success result with user
  def self.success(user:)
    new(status: :success, user: user)
  end

  # Create a failed authentication result
  #
  # @param reason [String] Reason for authentication failure
  # @param user [User, nil] User associated with failed attempt (optional)
  # @return [AuthResult] Failed result with reason
  def self.failed(reason, user: nil)
    new(status: :failed, reason: reason, user: user)
  end

  # Create a pending MFA authentication result
  #
  # @param user [User] User pending MFA verification
  # @return [AuthResult] Pending MFA result with user
  def self.pending_mfa(user:)
    new(status: :pending_mfa, user: user)
  end

  # Initialize a new AuthResult
  #
  # @param status [Symbol] Authentication status
  # @param user [User, nil] Associated user
  # @param reason [String, nil] Failure reason
  # @private Use class methods instead of direct initialization
  def initialize(status:, user: nil, reason: nil)
    @status = status
    @user = user
    @reason = reason
    freeze # Make instance immutable
  end

  # Check if authentication was successful
  #
  # @return [Boolean] true if status is :success
  def success?
    status == :success
  end

  # Check if authentication failed
  #
  # @return [Boolean] true if status is :failed
  def failed?
    status == :failed
  end

  # Check if MFA verification is pending
  #
  # @return [Boolean] true if status is :pending_mfa
  def pending_mfa?
    status == :pending_mfa
  end
end
