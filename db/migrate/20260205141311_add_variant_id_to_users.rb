class AddVariantIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :variant_id, :string
  end
end
