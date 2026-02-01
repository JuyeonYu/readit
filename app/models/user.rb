class User < ApplicationRecord
  has_many :messages
  has_many :notifications, through: :messages
  has_many :login_tokens, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
