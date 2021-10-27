class Operator::LineGroupsController < Operator::BaseController
  before_action :set_line_group, only: %i[show edit update destroy]

  def index
    @line_groups = LineGroup.all
  end

  def show
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private

  def set_line_group
  end
end
