class AddTokenToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :token, :string
    add_index :messages, :token, unique: true
  end
end
