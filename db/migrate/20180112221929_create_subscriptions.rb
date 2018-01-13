class CreateSubscriptions < ActiveRecord::Migration[5.2]
  def change
    create_table :subscriptions do |t|
      t.references :bot, foreign_key: true
      t.references :post_type, foreign_key: true

      t.timestamps
    end
  end
end
