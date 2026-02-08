class ApplicationMailer < ActionMailer::Base
  # Extract host without port for valid email address
  MAILER_HOST = ENV.fetch("APP_HOST", "localhost").split(":").first.freeze

  default from: email_address_with_name(
    ENV["RESEND_FROM"] || Rails.application.credentials.dig(:resend, :from) || "no-reply@#{MAILER_HOST}",
    "MessageOpen"
  )
  layout "mailer"
end
