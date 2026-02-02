class Message < ApplicationRecord
  belongs_to :user
  has_many :read_events, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_rich_text :content

  has_secure_password validations: false

  validates :token, presence: true, uniqueness: true
  validates :content, presence: true
  validates :expires_at, comparison: { greater_than: -> { Time.current } },
            if: -> { expires_at.present? && will_save_change_to_expires_at? }
  validates :password, length: { minimum: 6 }, allow_blank: true

  before_validation :generate_token, on: :create

  def sender_email
    user&.email
  end

  def readable?
    is_active &&
      (expires_at.nil? || expires_at.future?) &&
      (max_read_count.nil? || read_count < max_read_count)
  end

  def increment_read_count!
    increment!(:read_count)
  end

  def unique_reader_count
    read_events.distinct.count(:viewer_token_hash)
  end

  private

  def generate_token
    return if token.present?

    10.times do
      self.token = SecureRandom.urlsafe_base64(24)
      return unless Message.exists?(token: token)
    end

    errors.add(:token, "could not be generated")
  end
end
