class CreateCommands < ActiveRecord::Migration[5.2]
  def change
    create_table :commands do |t|
      t.references :bot, foreign_key: true
      t.string :name
      t.integer :type
      t.string :data
      t.boolean :reply
      t.boolean :privileged
      t.integer :min
      t.integer :max

      t.timestamps
    end
  end
end
