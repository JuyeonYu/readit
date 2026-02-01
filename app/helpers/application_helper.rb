module ApplicationHelper
  def notification_status_label(status)
    case status.to_s
    when "pending" then "대기중"
    when "sent" then "발송완료"
    when "failed" then "실패"
    else status
    end
  end

  def notification_type_label(notification_type)
    case notification_type.to_s
    when "email" then "이메일"
    when "web" then "웹"
    when "slack" then "슬랙"
    when "webhook" then "웹훅"
    else notification_type
    end
  end

  def format_datetime(time)
    time.strftime("%Y년 %m월 %d일 %H:%M")
  end

  def format_date_short(time)
    time.strftime("%m월 %d일 %H:%M")
  end
end
