module ApplicationHelper
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
