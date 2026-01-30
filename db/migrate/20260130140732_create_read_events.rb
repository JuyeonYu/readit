class CreateReadEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :read_events do |t|
      t.references :message, null: false, foreign_key: true
      t.datetime :read_at, default: -> { "CURRENT_TIMESTAMP" }
      t.string :user_agent
      t.string :viewer_token_hash

      t.timestamps
    end

    add_index :read_events, :viewer_token_hash
    add_index :read_events, :read_at
  end
end
