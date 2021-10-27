class Operator::LineGroupsController < Operator::BaseController
  before_action :set_line_group, only: %i[show edit update destroy]

  def index
    authorize(LineGroup)

    @line_groups = LineGroup.all
  end

  def show
    authorize(@line_group)
  end

  def edit
    authorize(@line_group)
  end

  def update
    authorize(@line_group)
  end

  def destroy
    authorize(@line_group)
  end

  private

  def set_line_group
    @line_group = LineGroup.find(params[:id])
  end
end
