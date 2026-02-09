class ApplicationMailer < ActionMailer::Base
  # Extract host without port for valid email address
  MAILER_HOST = URI.parse(ENV.fetch("APP_HOST", "localhost")).host || ENV.fetch("APP_HOST", "localhost").freeze

  default from: email_address_with_name(
    ENV["RESEND_FROM"] || Rails.application.credentials.dig(:resend, :from) || "notifications@#{MAILER_HOST}",
    "MessageOpen"
  ),
  reply_to: ENV["RESEND_REPLY_TO"].presence || "support@#{MAILER_HOST}"

  layout "mailer"
end
