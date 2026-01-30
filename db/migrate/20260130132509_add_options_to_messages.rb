class AddOptionsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :sender_email, :string
    add_column :messages, :password_digest, :string
    add_column :messages, :max_read_count, :integer
    add_column :messages, :expires_at, :datetime
  end
end
