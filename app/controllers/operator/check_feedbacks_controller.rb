class Operator::CheckFeedbacksController < Operator::BaseController
  before_action :set_feedback, only: %i[show destroy]

  def index
    authorize(Feedback)

    @feedbacks = Feedback.all
  end

  def show
    authorize(@feedback)
  end

  def destroy
    authorize(@feedback)

    @feedback.destroy!
    redirect_to operator_check_feedbacks_path, success: 'フィードバックを削除しました。'
  end

  private

  def set_content
    @feedback = Feedback.find(params[:id])
  end
end
