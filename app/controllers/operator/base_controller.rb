class Operator::BaseController < ApplicationController
  add_flash_types :success, :info, :warning, :danger
  layout 'operator/layouts/application'
  before_action :require_login

  private

  def not_authenticated
    redirect_to root_path
  end
end
