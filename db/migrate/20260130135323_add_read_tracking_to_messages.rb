class AddReadTrackingToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :read_count, :integer, default: 0, null: false
    add_column :messages, :is_active, :boolean, default: true, null: false
  end
end
