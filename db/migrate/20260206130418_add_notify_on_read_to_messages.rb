class AddNotifyOnReadToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :notify_on_read, :boolean, default: true, null: false
  end
end
