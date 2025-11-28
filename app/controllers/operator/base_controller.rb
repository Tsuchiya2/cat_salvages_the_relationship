class Operator::BaseController < ApplicationController
  include Authentication

  layout 'operator/layouts/application'
  before_action :require_authentication

  private

  # Pundit uses this method to determine the current user for policy checks
  def pundit_user
    current_operator
  end

  def not_authenticated
    redirect_to operator_cat_in_path,
                alert: I18n.t('authentication.errors.session_expired',
                              default: 'ログインが必要です')
  end
end
