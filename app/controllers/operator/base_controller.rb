class Operator::BaseController < ApplicationController
  layout 'operator/layouts/application'
  before_action :require_login

  private

  def not_authenticated
    redirect_to operator_cat_in_path, alert: 'Please login first'
  end
end
