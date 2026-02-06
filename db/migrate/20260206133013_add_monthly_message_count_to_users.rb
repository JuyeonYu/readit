class AddMonthlyMessageCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :monthly_message_count, :integer, default: 0, null: false
    add_column :users, :monthly_message_count_reset_at, :datetime
  end
end
