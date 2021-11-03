class Operator::AlarmContentsController < Operator::BaseController
  before_action :set_alarm_content, only: %i[show edit update destroy]

  def index
    authorize(AlarmContent)

    @alarm_contents = AlarmContent.order(id: :asc)
  end

  def show
    authorize(@alarm_content)
  end

  def new
    authorize(AlarmContent)

    @alarm_content = AlarmContent.new
  end

  def create
    authorize(AlarmContent)

    @alarm_content = AlarmContent.new(alarm_content_params)
    if @alarm_content.save
      redirect_to operator_alarm_contents_path, success: '新しくコンテンツを作成しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :new
    end
  end

  def edit
    authorize(@alarm_content)
  end

  def update
    authorize(@alarm_content)

    if @alarm_content.update(alarm_content_params)
      redirect_to operator_alarm_contents_path, success: 'コンテンツを更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    authorize(@alarm_content)

    @alarm_content.destroy!
    redirect_to operator_alarm_contents_path, success: 'コンテンツを削除しました。'
  end

  private

  def set_alarm_content
    @alarm_content = AlarmContent.find(params[:id])
  end

  def alarm_content_params
    params.require(:alarm_content).permit(:body, :category)
  end
end
