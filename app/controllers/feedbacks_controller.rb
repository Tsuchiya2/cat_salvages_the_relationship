class FeedbacksController < ApplicationController
  def new
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(feedback_params)
    if @feedback.save
      redirect_to root_path, success: 'フィードバックありがとうございます！'
    else
      flash.now[:danger] = '100〜300文字でお願いします！🐾'
      render :new
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:text)
  end
end
