class Operator::OperatorSessionsController < Operator::BaseController
  skip_before_action :require_authentication, only: %i[new create]

  def new
    redirect_to operator_operates_path if operator_signed_in?
  end

  def create
    operator = authenticate_operator(params[:email], params[:password])

    if operator
      login(operator)
      redirect_to operator_operates_path, notice: I18n.t('authentication.messages.login_success', default: 'キャットイン')
    else
      flash.now[:alert] = I18n.t('authentication.errors.invalid_credentials', default: 'メールアドレスまたはパスワードが正しくありません')
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to operator_cat_in_path, notice: I18n.t('authentication.messages.logout_success', default: 'キャットアウト')
  end
end
