class Operator::ContentCategoriesController < Operator::BaseController
  before_action :set_content_category, only: %i[show edit update destroy]

  def index
    @content_categories = ContentCategory.all
  end

  def show; end

  def new
    @content_category = ContentCategory.new
  end

  def create
    @content_category = ContentCategory.new(content_category_params)
    if @content_category.save
      redirect_to operator_content_categories_path, success: '新しくカテゴリーを作成しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :new
    end
  end

  def edit; end

  def update
    if @content_category.update(content_category_params)
      redirect_to operator_content_categories_path, success: 'カテゴリーを更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    @content_category.destroy!
    redirect_to operator_content_categories_path, success: 'カテゴリーを関連ごと削除しました。'
  end

  private

  def set_content_category
    @content_category = ContentCategory.find(params[:id])
  end

  def content_category_params
    params.require(:content_category).permit(:name)
  end
end
