class Message < ApplicationRecord
  belongs_to :user

  has_secure_password validations: false

  validates :content, presence: true
  validates :expires_at, comparison: { greater_than: -> { Time.current } },
            if: -> { expires_at.present? && will_save_change_to_expires_at? }
  validates :password, length: { minimum: 6 }, allow_blank: true

  def sender_email
    user&.email
  end
end
