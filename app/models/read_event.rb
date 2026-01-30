class ReadEvent < ApplicationRecord
  belongs_to :message

  validates :message_id, presence: true
end
