class ApplicationMailer < ActionMailer::Base
  default from: ENV["RESEND_FROM"] || Rails.application.credentials.dig(:resend, :from) || "no-reply@#{ENV.fetch('APP_HOST', 'localhost')}"
  layout "mailer"
end
