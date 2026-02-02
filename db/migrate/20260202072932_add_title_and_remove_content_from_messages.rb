class AddTitleAndRemoveContentFromMessages < ActiveRecord::Migration[8.1]
  def up
    # First add column allowing NULL
    add_column :messages, :title, :string

    # Set default title for existing records
    Message.reset_column_information
    Message.find_each do |message|
      message.update_column(:title, "Untitled Message")
    end

    # Now make it NOT NULL
    change_column_null :messages, :title, false

    # Remove old content column
    remove_column :messages, :content, :text
  end

  def down
    add_column :messages, :content, :text
    remove_column :messages, :title
  end
end
