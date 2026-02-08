class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(
    ENV["RESEND_FROM"] || Rails.application.credentials.dig(:resend, :from) || "no-reply@#{ENV.fetch('APP_HOST', 'localhost')}",
    "MessageOpen"
  )
  layout "mailer"
end
