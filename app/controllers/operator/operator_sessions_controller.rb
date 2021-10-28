class Operator::OperatorSessionsController < Operator::BaseController
  skip_before_action :require_login, only: %i[new create]

  def new; end

  def create
    @operator = login(params[:email], params[:password])

    if @operator
      redirect_to operator_operates_path, success: 'キャットインしました。'
    else
      render :new
    end
  end

  def destroy
    logout
    redirect_to operator_cat_in_path, success: 'キャットアウトしました。'
  end
end
