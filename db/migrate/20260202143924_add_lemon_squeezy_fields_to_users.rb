class AddLemonSqueezyFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :lemon_squeezy_customer_id, :string
    add_column :users, :lemon_squeezy_subscription_id, :string
    add_column :users, :subscription_status, :string
    add_column :users, :plan, :string, default: "free"
    add_column :users, :current_period_end, :datetime
    add_column :users, :cancelled_at, :datetime

    add_index :users, :lemon_squeezy_customer_id
    add_index :users, :lemon_squeezy_subscription_id
  end
end
