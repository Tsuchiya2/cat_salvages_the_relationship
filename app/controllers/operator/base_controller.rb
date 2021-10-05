class Operator::BaseController < ApplicationController
  layout 'operator/layouts/application'
  before_action :require_login

  private

  def not_authenticated
    redirect_to operator_login_path, alert: 'Please login first'
  end
end
