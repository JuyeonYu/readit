class ReadMessageService
  Result = Struct.new(:success?, :read_event, :error, keyword_init: true)

  def self.call(message, viewer_token_hash:, user_agent: nil)
    read_event = nil

    ActiveRecord::Base.transaction do
      message.with_lock do
        unless message.readable?
          return Result.new(success?: false, error: I18n.t("errors.message_unreadable"))
        end

        message.increment_read_count!

        read_event = message.read_events.create!(
          viewer_token_hash: viewer_token_hash,
          user_agent: user_agent,
          read_at: Time.current
        )
      end
    end

    # Send notification (async, outside transaction)
    if message.sender_email.present? && message.notify_on_read?
      SendNotificationJob.perform_later(message.id, viewer_token_hash)
    end

    Result.new(success?: true, read_event: read_event)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, error: e.message)
  end
end
