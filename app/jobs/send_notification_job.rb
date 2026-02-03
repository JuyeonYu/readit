class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id, viewer_token_hash)
    message = Message.find(message_id)
    return unless message.sender_email.present?

    # Generate idempotency_key (once per unique viewer)
    idempotency_key = "message:#{message_id}:viewer:#{viewer_token_hash}"

    # Prevent duplicates (find_or_create_by)
    notification = message.notifications.find_or_create_by!(
      idempotency_key: idempotency_key
    ) do |n|
      n.notification_type = :email
      n.recipient = message.sender_email
      n.status = :pending
    end

    # Skip if already sent
    return if notification.sent?

    # Send email
    begin
      MessageMailer.read_notification(message).deliver_now
      notification.update!(status: :sent, sent_at: Time.current)
    rescue => e
      notification.update!(status: :failed)
      raise
    end
  end
end
