class AddReactionToReadEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :read_events, :reaction, :string
  end
end
