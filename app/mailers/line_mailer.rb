class LineMailer < ApplicationMailer
  def event_error_email(group_id, error)
    @group_id = group_id
    @error = error
    mail(to: 'operator@example.com', subject: '[Error通知]LINEイベント')
  end
end
