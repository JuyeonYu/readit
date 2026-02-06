class User < ApplicationRecord
  has_many :messages
  has_many :notifications, through: :messages
  has_many :login_tokens, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Subscription status constants
  SUBSCRIPTION_STATUSES = %w[active cancelled expired past_due paused].freeze
  PLANS = %w[free pro].freeze
  FREE_MESSAGE_LIMIT = 10
  FREE_HISTORY_DAYS = 7

  # Admin check
  def admin?
    email.present? && email == ENV["ADMIN_EMAIL"]
  end

  # Plan checks
  def pro?
    admin? || (plan == "pro" && subscription_active?)
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
    reset_monthly_message_count_if_needed
    monthly_message_count
  end

  def message_limit
    return Float::INFINITY if pro?
    FREE_MESSAGE_LIMIT
  end

  def at_message_limit?
    free? && messages_this_month >= message_limit
  end

  def history_limit_date
    return nil if pro?
    FREE_HISTORY_DAYS.days.ago
  end

  def increment_monthly_message_count!
    reset_monthly_message_count_if_needed
    increment!(:monthly_message_count)
  end

  def reset_monthly_message_count_if_needed
    return if monthly_message_count_reset_at.present? &&
              monthly_message_count_reset_at >= Time.current.beginning_of_month

    update_columns(
      monthly_message_count: 0,
      monthly_message_count_reset_at: Time.current
    )
  end

  # Subscription management
  def activate_subscription!(customer_id:, subscription_id:, variant_id: nil, current_period_end:)
    update!(
      lemon_squeezy_customer_id: customer_id,
      lemon_squeezy_subscription_id: subscription_id,
      variant_id: variant_id,
      subscription_status: "active",
      plan: "pro",
      current_period_end: current_period_end,
      cancelled_at: nil
    )
  end

  # Plan type based on variant_id
  def pro_monthly?
    pro? && variant_id == Rails.application.config.lemon_squeezy[:pro_monthly_variant_id]
  end

  def pro_yearly?
    pro? && variant_id == Rails.application.config.lemon_squeezy[:pro_yearly_variant_id]
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
