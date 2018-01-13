class CreateBots < ActiveRecord::Migration[5.2]
  def change
    create_table :bots do |t|
      t.references :user, foreign_key: true
      t.string :name
      t.string :token
      t.integer :scan_method
      t.string :route
      t.string :spam_key
      t.integer :key_type
      t.string :chat_template

      t.timestamps
    end
  end
end
