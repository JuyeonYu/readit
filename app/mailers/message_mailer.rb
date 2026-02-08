class MessageMailer < ApplicationMailer
  def read_notification(message)
    @message = message
    @read_count = message.read_count

    mail(
      to: message.sender_email,
      subject: "#{message.title} - Opened by recipient"
    )
  end

  def welcome(user)
    @user = user
    mail(
      to: @user.email,
      subject: "Welcome to MessageOpen"
    )
  end

  def weekly_digest(user, stats)
    @user = user
    @stats = stats
    mail(
      to: @user.email,
      subject: "Your weekly message report"
    )
  end

  def upgrade_prompt(user)
    @user = user
    mail(
      to: @user.email,
      subject: "You're running low on messages"
    )
  end
end
