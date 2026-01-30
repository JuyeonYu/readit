class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :message, null: false, foreign_key: true
      t.integer :notification_type, default: 0, null: false
      t.string :recipient, null: false
      t.integer :status, default: 0, null: false
      t.string :idempotency_key, null: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notifications, :idempotency_key, unique: true
    add_index :notifications, %i[message_id status]
    add_index :notifications, :sent_at
  end
end
