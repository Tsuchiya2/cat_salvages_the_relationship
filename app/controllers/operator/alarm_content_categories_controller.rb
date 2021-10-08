class Operator::AlarmContentCategoriesController < Operator::BaseController
  before_action :set_alarm_content_category, only: %i[show edit update destroy]

  def index
    @alram_content_categories = AlarmContentCategory.all
  end

  def show; end

  def new
    @alarm_content_category = AlarmContentCategory.new
  end

  def create
    @alarm_content_category = AlarmContentCategory.new(alarm_content_category_params)
    if @alarm_content_category.save
      redirect_to operator_alarm_content_categories_path, success: '新しくアラームカテゴリーを作成しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :new
    end
  end

  def edit; end

  def update
    if @alarm_content_category.update(alarm_content_category_params)
      redirect_to operator_alarm_content_categories_path, success: 'アラームカテゴリーを更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    @alarm_content_category.destroy!
    redirect_to operator_alarm_content_categories_path, success: 'アラームカテゴリーを関連ごと削除しました。'
  end

  private

  def set_alarm_content_category
    @alarm_content_category = AlarmContentCategory.find(params[:id])
  end

  def alarm_content_category_params
    params.require(:alarm_content_category).permit(:name)
  end
end
