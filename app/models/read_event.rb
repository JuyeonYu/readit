class ReadEvent < ApplicationRecord
  belongs_to :message

  ALLOWED_REACTIONS = %w[👍 ❤️ 😊 🎉 🙏].freeze

  validates :message_id, presence: true
  validates :reaction, inclusion: { in: ALLOWED_REACTIONS }, allow_nil: true
end
