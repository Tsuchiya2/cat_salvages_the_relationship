class FeedbackPolicy < ApplicationPolicy
  def index?
    user.operator? || user.guest?
  end

  def show?
    user.operator?
  end

  def destroy?
    user.operator?
  end
end
