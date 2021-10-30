class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com', to: Rails.application.credentials.operator[:email]
  layout 'mailer'
end
