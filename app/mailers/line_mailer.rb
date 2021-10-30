class LineMailer < ApplicationMailer
  def error_email(group_id, error_message)
    @group_id       = group_id
    @error_message  = error_message
    mail(subject: '【Error通知】LINEとの通信において')
  end
end
