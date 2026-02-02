class AddTitleAndRemoveContentFromMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :title, :string, null: false
    remove_column :messages, :content, :text
  end
end
