class ApplicationMailer < ActionMailer::Base
  default from: ENV["RESEND_FROM"] || Rails.application.credentials.dig(:resend, :from) || "no-reply@messageopen.com"
  layout "mailer"
end
