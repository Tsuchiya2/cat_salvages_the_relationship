class Operator::LineGroupsController < Operator::BaseController
  before_action :set_line_group, only: %i[show edit update destroy]

  def index
    authorize(LineGroup)

    @line_groups = LineGroup.all
    @all_post_count = @line_groups.sum(:post_count)
  end

  def show
    authorize(@line_group)
  end

  def edit
    authorize(@line_group)
  end

  def update
    authorize(@line_group)

    if @line_group.update(line_group_params)
      redirect_to operator_line_groups_path, success: 'LINEグループ情報の一部を更新しました。'
    else
      flash.now[:danger] = '入力に不備がありました。'
      render :edit
    end
  end

  def destroy
    authorize(@line_group)

    @line_group.destroy!
    redirect_to operator_line_groups_path, success: 'LINEグループ情報を削除しました。'
  end

  private

  def set_line_group
    @line_group = LineGroup.find(params[:id])
  end

  def line_group_params
    params.require(:line_group).permit(:remind_at, :status, :post_count)
  end
end
