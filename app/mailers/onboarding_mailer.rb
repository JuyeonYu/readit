class OnboardingMailer < ApplicationMailer
  # Day 0: Welcome email (immediately after signup)
  def welcome(user)
    @user = user
    @name = user.email.split("@").first.capitalize

    mail(
      to: @user.email,
      subject: "Welcome to MessageOpen!"
    )
  end

  # Day 3: Pro introduction email
  def pro_introduction(user)
    @user = user
    @name = user.email.split("@").first.capitalize

    mail(
      to: @user.email,
      subject: "Loving MessageOpen? Here's what Pro offers"
    )
  end

  # When 8/10 messages used: Limit warning
  def limit_warning(user, messages_used, reset_date)
    @user = user
    @name = user.email.split("@").first.capitalize
    @messages_used = messages_used
    @message_limit = 10
    @reset_date = reset_date

    mail(
      to: @user.email,
      subject: "You've used #{messages_used} of #{@message_limit} free messages"
    )
  end

  # When 10/10 messages used: Limit reached
  def limit_reached(user, reset_date)
    @user = user
    @name = user.email.split("@").first.capitalize
    @reset_date = reset_date

    mail(
      to: @user.email,
      subject: "You've reached your monthly limit"
    )
  end
end
