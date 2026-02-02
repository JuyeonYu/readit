class User < ApplicationRecord
  has_many :messages
  has_many :notifications, through: :messages
  has_many :login_tokens, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  # Subscription status constants
  SUBSCRIPTION_STATUSES = %w[active cancelled expired past_due paused].freeze
  PLANS = %w[free pro].freeze

  # Plan checks
  def pro?
    plan == "pro" && subscription_active?
  end

  def free?
    !pro?
  end

  def subscription_active?
    subscription_status == "active" && (current_period_end.nil? || current_period_end > Time.current)
  end

  def subscription_cancelled?
    subscription_status == "cancelled"
  end

  def subscription_past_due?
    subscription_status == "past_due"
  end

  # Grace period: still pro if cancelled but period hasn't ended
  def in_grace_period?
    subscription_cancelled? && current_period_end.present? && current_period_end > Time.current
  end

  # Message limits
  def messages_this_month
    messages.where("created_at >= ?", Time.current.beginning_of_month).count
  end

  def message_limit
    pro? ? Float::INFINITY : 10
  end

  def at_message_limit?
    free? && messages_this_month >= message_limit
  end

  # Subscription management
  def activate_subscription!(customer_id:, subscription_id:, current_period_end:)
    update!(
      lemon_squeezy_customer_id: customer_id,
      lemon_squeezy_subscription_id: subscription_id,
      subscription_status: "active",
      plan: "pro",
      current_period_end: current_period_end,
      cancelled_at: nil
    )
  end

  def cancel_subscription!
    update!(
      subscription_status: "cancelled",
      cancelled_at: Time.current
    )
  end

  def expire_subscription!
    update!(
      subscription_status: "expired",
      plan: "free"
    )
  end

  def update_subscription_period!(current_period_end:)
    update!(
      current_period_end: current_period_end,
      subscription_status: "active"
    )
  end

  def send_welcome_email
    OnboardingMailer.welcome(self).deliver_later
  end
end
