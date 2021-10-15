class Operator::ContentsController < Operator::BaseController
  before_action :set_content, only: %i[show edit update destroy]

  def index
    authorize(Content)

    @contents = Content.all
  end

  def show
    authorize(@content)
  end

  def new
    authorize(Content)

    @content = Content.new
  end

  def create
    authorize(Content)

    @content = Content.new(content_params)
    if @content.save
      redirect_to operator_contents_path, success: '新しくコンテンツを作成しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :new
    end
  end

  def edit
    authorize(@content)
  end

  def update
    authorize(@content)

    if @content.update(content_params)
      redirect_to operator_contents_path, success: 'コンテンツを更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    authorize(@content)

    @content.destroy!
    redirect_to operator_contents_path, success: 'コンテンツを削除しました。'
  end

  private

  def set_content
    @content = Content.find(params[:id])
  end

  def content_params
    params.require(:content).permit(:body, :category)
  end
end
