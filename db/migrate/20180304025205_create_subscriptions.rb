class CreateSubscriptions < ActiveRecord::Migration[5.2]
  def change
    create_table :subscriptions do |t|
      t.references :bot, foreign_key: true
      t.references :post_type, foreign_key: true
      t.references :site, foreign_key: true
      t.boolean :all_sites
      t.string :route
      t.integer :request_method
      t.string :route
      t.string :spam_key
      t.integer :key_type
      t.string :answer_key
      t.integer :min_score
      t.string :chat_template
      t.string :web_template

      t.timestamps
    end
  end
end
