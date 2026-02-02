# frozen_string_literal: true

class OnboardingService
  MESSAGE_LIMIT = 10

  def initialize(user)
    @user = user
  end

  # Send welcome email immediately after signup
  def send_welcome
    OnboardingMailer.welcome(@user).deliver_later
  end

  # Send Pro introduction email (called via scheduled job on Day 3)
  def send_pro_introduction
    return if @user.pro? # Don't send if already Pro

    OnboardingMailer.pro_introduction(@user).deliver_later
  end

  # Check and send limit warning if at 80% usage
  def check_limit_warning
    return if @user.pro?

    messages_this_month = messages_count_this_month
    return unless messages_this_month == 8 # Exactly 8, send once

    reset_date = Time.current.end_of_month.to_date + 1.day
    OnboardingMailer.limit_warning(@user, messages_this_month, reset_date).deliver_later
  end

  # Check and send limit reached notification
  def check_limit_reached
    return if @user.pro?

    messages_this_month = messages_count_this_month
    return unless messages_this_month == MESSAGE_LIMIT # Exactly at limit, send once

    reset_date = Time.current.end_of_month.to_date + 1.day
    OnboardingMailer.limit_reached(@user, reset_date).deliver_later
  end

  # Check usage after creating a message
  def after_message_created
    messages_this_month = messages_count_this_month

    case messages_this_month
    when 8
      check_limit_warning
    when MESSAGE_LIMIT
      check_limit_reached
    end
  end

  private

  def messages_count_this_month
    @user.messages.where("created_at >= ?", Time.current.beginning_of_month).count
  end
end
