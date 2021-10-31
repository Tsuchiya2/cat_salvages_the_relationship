class SessionMailer < ApplicationMailer
  def notice(operator, access_ip)
    @operator = operator
    @access_ip = access_ip
    mail(subject: '【Warning】ロック状態のアカウントにアクセスがありました')
  end
end
