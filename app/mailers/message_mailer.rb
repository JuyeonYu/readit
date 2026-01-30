class MessageMailer < ApplicationMailer
  def read_notification(message)
    @message = message
    @read_count = message.read_count

    mail(
      to: message.sender_email,
      subject: "[읽었어?] 메시지가 읽혔습니다"
    )
  end
end
