class ReadMessageService
  Result = Struct.new(:success?, :read_event, :error, keyword_init: true)

  def self.call(message, viewer_token_hash:, user_agent: nil)
    read_event = nil

    ActiveRecord::Base.transaction do
      message.with_lock do
        unless message.readable?
          return Result.new(success?: false, error: "더 이상 읽을 수 없습니다")
        end

        message.increment_read_count!

        read_event = message.read_events.create!(
          viewer_token_hash: viewer_token_hash,
          user_agent: user_agent,
          read_at: Time.current
        )
      end
    end

    # 알림 발송 (비동기, 트랜잭션 밖)
    if message.sender_email.present?
      SendNotificationJob.perform_later(message.id)
    end

    Result.new(success?: true, read_event: read_event)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, error: e.message)
  end
end
