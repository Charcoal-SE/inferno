class CreateCommands < ActiveRecord::Migration[5.2]
  def change
    create_table :commands do |t|
      t.references :bot, foreign_key: true
      t.string :name
      t.integer :command_type
      t.string :data

      t.timestamps
    end
  end
end
