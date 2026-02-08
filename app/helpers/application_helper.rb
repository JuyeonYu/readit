module ApplicationHelper
  include Pagy::Frontend

  # Screenshot mode helpers - replaces dev URLs with production URLs
  def screenshot_mode?
    Rails.configuration.x.screenshot_mode rescue false
  end

  def display_host
    screenshot_mode? ? Rails.configuration.x.production_host : request.host
  end

  def display_base_url
    screenshot_mode? ? Rails.configuration.x.production_url : request.base_url
  end

  def support_email
    ENV.fetch("SUPPORT_EMAIL", "support@#{display_host}")
  end

  def display_message_url(token)
    if screenshot_mode?
      "#{Rails.configuration.x.production_url}/m/#{token}"
    else
      read_message_url(token)
    end
  end

  def notification_status_label(status)
    I18n.t("notifications.status.#{status}", default: status.to_s.titleize)
  end

  def notification_type_label(notification_type)
    I18n.t("notifications.type.#{notification_type}", default: notification_type.to_s.titleize)
  end

  def format_datetime(time)
    time.strftime("%b %d, %Y at %H:%M")
  end

  def format_date_short(time)
    time.strftime("%b %d, %H:%M")
  end
end
