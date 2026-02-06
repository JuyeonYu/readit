class LoginToken < ApplicationRecord
  EXPIRATION_PERIOD = 15.minutes

  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def valid_token?
    used_at.nil? && expires_at.future?
  end

  def use!
    update!(used_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= EXPIRATION_PERIOD.from_now
  end
end
