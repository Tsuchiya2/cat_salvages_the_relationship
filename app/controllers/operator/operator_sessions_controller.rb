class Operator::OperatorSessionsController < Operator::BaseController
  skip_before_action :require_login, only: %i[new create]

  def new; end

  def create
    @operator = login(params[:email], params[:password])

    if @operator
      redirect_to operator_boards_path
    else
      render :new
    end
  end

  def destroy
    logout
    redirect_to operator_cat_in_path
  end
end
