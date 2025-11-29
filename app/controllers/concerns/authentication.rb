# frozen_string_literal: true

# Authentication Concern
#
# Provides authentication-related methods for controllers, including:
# - Authentication with password credentials
# - Session management (login, logout)
# - Current operator tracking
# - Authorization helpers
#
# This concern integrates with:
# - AuthenticationService for credential verification
# - BruteForceProtection for account locking
# - Session management for security
#
# Usage:
#   class Operator::BaseController < ApplicationController
#     include Authentication
#
#     before_action :require_authentication
#   end
#
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_operator
    helper_method :current_operator
    helper_method :operator_signed_in?
  end

  # Authenticate operator with email and password
  #
  # This method attempts to authenticate an operator and handles:
  # - Successful authentication
  # - Failed authentication with account locking
  # - Notification emails for locked accounts
  #
  # @param email [String] Operator's email address
  # @param password [String] Operator's password
  # @return [Operator, nil] Authenticated operator or nil if authentication failed
  #
  # @example Successful authentication
  #   operator = authenticate_operator('operator@example.com', 'password123')
  #   login(operator) if operator
  #
  # @example Failed authentication with locked account
  #   operator = authenticate_operator('operator@example.com', 'wrong_password')
  #   # operator is nil, and notification email is sent if account is locked
  #
  def authenticate_operator(email, password)
    result = AuthenticationService.authenticate(
      :password,
      email: email,
      password: password,
      ip_address: request.remote_ip
    )

    if result.success?
      result.user
    elsif result.failed? && result.reason == :account_locked
      # Send notification email when account is locked
      result.user&.mail_notice(request.remote_ip)
      nil
    end
  end

  # Log in an operator and establish a session
  #
  # This method:
  # - Resets the session to prevent session fixation attacks
  # - Sets the operator_id in the session
  # - Caches the current operator in an instance variable
  #
  # @param operator [Operator] The operator to log in
  # @return [Operator] The logged-in operator
  #
  # @example
  #   operator = Operator.find_by(email: params[:email])
  #   login(operator)
  #
  def login(operator)
    reset_session # Prevent session fixation attacks
    session[:operator_id] = operator.id
    @current_operator = operator
  end

  # Log out the current operator and destroy the session
  #
  # This method:
  # - Resets the session completely
  # - Clears the current operator instance variable
  #
  # @return [nil]
  #
  # @example
  #   logout
  #   redirect_to operator_cat_in_path
  #
  def logout
    reset_session
    @current_operator = nil
  end

  # Get the currently logged-in operator
  #
  # @return [Operator, nil] The current operator or nil if not logged in
  #
  # @example In controller
  #   current_operator.name
  #
  # @example In view (via helper_method)
  #   <%= current_operator.email %>
  #
  def current_operator
    @current_operator
  end

  # Check if an operator is currently logged in
  #
  # @return [Boolean] true if operator is logged in, false otherwise
  #
  # @example In controller
  #   redirect_to operator_cat_in_path unless operator_signed_in?
  #
  # @example In view (via helper_method)
  #   <% if operator_signed_in? %>
  #     <%= link_to 'ログアウト', operator_cat_out_path, method: :delete %>
  #   <% end %>
  #
  def operator_signed_in?
    current_operator.present?
  end

  # Require authentication before accessing an action
  #
  # This method should be used as a before_action callback to ensure
  # that only authenticated operators can access certain actions.
  #
  # If the operator is not authenticated, redirects to the login page
  # with an appropriate error message.
  #
  # @return [void]
  #
  # @example
  #   class Operator::ContentsController < ApplicationController
  #     include Authentication
  #     before_action :require_authentication
  #   end
  #
  def require_authentication
    return if operator_signed_in?

    not_authenticated
  end

  # Handle unauthenticated access attempts
  #
  # This method is called when an unauthenticated user attempts to
  # access a protected resource. It redirects to the login page with
  # an error message.
  #
  # Override this method in your controller to customize the behavior.
  #
  # @return [void]
  #
  # @example Custom not_authenticated behavior
  #   def not_authenticated
  #     respond_to do |format|
  #       format.html { redirect_to operator_cat_in_path, alert: 'ログインが必要です' }
  #       format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
  #     end
  #   end
  #
  def not_authenticated
    redirect_to operator_cat_in_path,
                alert: I18n.t('authentication.errors.session_expired',
                              default: 'ログインが必要です')
  end

  private

  # Set the current operator from the session
  #
  # This method is called as a before_action to set up the current_operator
  # for each request. It retrieves the operator from the database using the
  # operator_id stored in the session.
  #
  # If the operator is not found or the session is invalid, it resets the
  # session and returns nil.
  #
  # @return [Operator, nil] The current operator or nil
  #
  def set_current_operator
    return unless session[:operator_id]

    @current_operator ||= Operator.find_by(id: session[:operator_id])

    # Reset session if operator not found
    reset_session if @current_operator.nil? && session[:operator_id].present?

    @current_operator
  rescue ActiveRecord::RecordNotFound
    reset_session
    nil
  end
end
