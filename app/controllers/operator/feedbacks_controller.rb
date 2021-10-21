class Operator::FeedbacksController < Operator::BaseController
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
    redirect_to operator_feedbacks_path, success: 'コンテンツを削除しました。'
  end

  private

  def set_feedback
    @feedback = Feedback.find(params[:id])
  end
end
