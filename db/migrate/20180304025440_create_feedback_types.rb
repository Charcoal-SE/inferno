class CreateFeedbackTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :feedback_types do |t|
      t.references :bot, foreign_key: true
      t.string :name
      t.integer :type
      t.string :icon
      t.boolean :blacklist

      t.timestamps
    end
  end
end
