class AddWebhookUrlToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webhook_url, :string
  end
end
