class Operator::ContentsController < Operator::BaseController
  before_action :set_content, only: %i[show edit update destroy]

  def index
    @contents = Content.all.includes(:content_category)
  end

  def show; end

  def new
    @content = Content.new
  end

  def create
    @content = Content.new(content_params)
    if @content.save
      redirect_to operator_contents_path, success: '新しくコンテンツを作成しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :new
    end
  end

  def edit; end

  def update
    if @content.update(content_params)
      redirect_to operator_contents_path, success: 'コンテンツを更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    @content.destroy!
    redirect_to operator_contents_path, success: 'コンテンツを削除しました。'
  end

  private

  def set_content
    # N+1問題が発生したら「.includes(:content_category)」を追加予定です。
    @content = Content.find(params[:id])
  end

  def content_params
    # content_category_idの記述を追加する必要があります。
    params.require(:content).permit(:body)
  end
end
