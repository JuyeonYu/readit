module ApplicationHelper
  def notification_status_label(status)
    case status.to_s
    when "pending" then "Pending"
    when "sent" then "Sent"
    when "failed" then "Failed"
    else status.to_s.titleize
    end
  end

  def notification_type_label(notification_type)
    case notification_type.to_s
    when "email" then "Email"
    when "web" then "Web"
    when "slack" then "Slack"
    when "webhook" then "Webhook"
    else notification_type.to_s.titleize
    end
  end

  def format_datetime(time)
    time.strftime("%b %d, %Y at %H:%M")
  end

  def format_date_short(time)
    time.strftime("%b %d, %H:%M")
  end
end
