# frozen_string_literal: true

# Generic session lifecycle management service
#
# This service provides session management capabilities for multiple user types
# (Operator, Admin, Customer, etc.) with consistent API and security features.
#
# Features:
# - Create and destroy sessions
# - Retrieve current user from session
# - Session timeout validation
# - Support for multiple user types via model_class parameter
#
# @example Creating a session for an Operator
#   operator = Operator.find_by(email: 'admin@example.com')
#   SessionManager.create_session(operator, session)
#
# @example Creating a session with custom key
#   customer = Customer.find(123)
#   SessionManager.create_session(customer, session, key: :customer_id)
#
# @example Retrieving current user
#   operator = SessionManager.current_user(session, Operator)
#   customer = SessionManager.current_user(session, Customer, key: :customer_id)
#
# @example Validating session timeout
#   if SessionManager.valid_session?(session, timeout: 30.minutes)
#     # Session is still valid
#   else
#     # Session has expired
#   end
#
# @example Destroying session
#   SessionManager.destroy_session(session)
#
class SessionManager
  class << self
    # Create a new session for a user
    #
    # Stores the user ID in the session and records session creation timestamp
    # for timeout validation.
    #
    # @param user [ApplicationRecord] User instance (Operator, Admin, Customer, etc.)
    # @param session [ActionDispatch::Request::Session] Rails session object
    # @param key [Symbol] Session key to store user ID (default: :user_id)
    #
    # @return [void]
    #
    # @example Create session for operator
    #   operator = Operator.find(1)
    #   SessionManager.create_session(operator, session)
    #
    # @example Create session with custom key
    #   customer = Customer.find(1)
    #   SessionManager.create_session(customer, session, key: :customer_id)
    def create_session(user, session, key: :user_id)
      session[key] = user.id
      session[:session_created_at] = Time.current
    end

    # Destroy a session
    #
    # Clears all session data, effectively logging out the user.
    #
    # @param session [ActionDispatch::Request::Session] Rails session object
    #
    # @return [void]
    #
    # @example
    #   SessionManager.destroy_session(session)
    def destroy_session(session)
      session.clear
    end

    # Retrieve current user from session
    #
    # Looks up user by ID stored in session. Returns nil if user ID is not found
    # or if the user no longer exists in the database.
    #
    # @param session [ActionDispatch::Request::Session] Rails session object
    # @param model_class [Class] User model class (Operator, Admin, Customer, etc.)
    # @param key [Symbol] Session key where user ID is stored (default: :user_id)
    #
    # @return [ApplicationRecord, nil] User instance or nil if not found
    #
    # @example Get current operator
    #   operator = SessionManager.current_user(session, Operator)
    #
    # @example Get current customer with custom key
    #   customer = SessionManager.current_user(session, Customer, key: :customer_id)
    def current_user(session, model_class, key: :user_id)
      return nil unless session[key]

      model_class.find_by(id: session[key])
    end

    # Check if session is still valid (not expired)
    #
    # Validates session based on creation timestamp. Returns false if:
    # - Session creation timestamp is missing
    # - Session has exceeded the timeout duration
    #
    # @param session [ActionDispatch::Request::Session] Rails session object
    # @param timeout [ActiveSupport::Duration] Session timeout duration (default: 30.minutes)
    #
    # @return [Boolean] true if session is valid, false if expired or missing timestamp
    #
    # @example Check with default timeout (30 minutes)
    #   if SessionManager.valid_session?(session)
    #     # Session is valid
    #   end
    #
    # @example Check with custom timeout
    #   if SessionManager.valid_session?(session, timeout: 1.hour)
    #     # Session is valid
    #   end
    def valid_session?(session, timeout: 30.minutes)
      return false unless session[:session_created_at]

      Time.zone.parse(session[:session_created_at].to_s) > timeout.ago
    end
  end
end
