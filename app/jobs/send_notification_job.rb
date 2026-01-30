class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find(message_id)
    return unless message.sender_email.present?

    # idempotency_key 생성 (5분 버킷)
    bucket = (Time.current.to_i / 300) * 300
    idempotency_key = "message:#{message_id}:email:#{bucket}"

    # 중복 방지 (find_or_create_by)
    notification = message.notifications.find_or_create_by!(
      idempotency_key: idempotency_key
    ) do |n|
      n.notification_type = :email
      n.recipient = message.sender_email
      n.status = :pending
    end

    # 이미 발송됐으면 skip
    return if notification.sent?

    # 메일 발송
    begin
      MessageMailer.read_notification(message).deliver_now
      notification.update!(status: :sent, sent_at: Time.current)
    rescue => e
      notification.update!(status: :failed)
      raise
    end
  end
end
