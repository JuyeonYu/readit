class Notification < ApplicationRecord
  belongs_to :message

  enum :status, { pending: 0, sent: 1, failed: 2 }
  enum :notification_type, { email: 0, web: 1, slack: 2, webhook: 3 }

  validates :message_id, :recipient, :notification_type, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
end
