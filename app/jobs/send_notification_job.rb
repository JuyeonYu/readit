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
    if notification.sent?
      Rails.logger.info "[SendNotificationJob] Notification already sent for message #{message_id}, skipping"
      return
    end

    # Send email
    begin
      Rails.logger.info "[SendNotificationJob] Sending email to #{message.sender_email} for message #{message.id}"
      MessageMailer.read_notification(message).deliver_now
      Rails.logger.info "[SendNotificationJob] Email sent successfully to #{message.sender_email}"
      notification.update!(status: :sent, sent_at: Time.current)
    rescue => e
      Rails.logger.error "[SendNotificationJob] Failed to send email: #{e.message}"
      notification.update!(status: :failed)
      raise
    end

    # Also send webhook for Pro users
    if message.user&.pro? && message.user&.webhook_url.present?
      SendWebhookJob.perform_later(message_id, viewer_token_hash)
    end
  end
end
