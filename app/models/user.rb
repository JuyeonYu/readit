class User < ApplicationRecord
  has_many :messages
  has_many :notifications, through: :messages
  has_many :login_tokens, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  # TODO: Replace with actual billing check when payments are implemented
  def pro?
    false
  end

  def free?
    !pro?
  end

  def messages_this_month
    messages.where("created_at >= ?", Time.current.beginning_of_month).count
  end

  def message_limit
    pro? ? Float::INFINITY : 10
  end

  def at_message_limit?
    free? && messages_this_month >= message_limit
  end

  def send_welcome_email
    OnboardingMailer.welcome(self).deliver_later
  end
end
