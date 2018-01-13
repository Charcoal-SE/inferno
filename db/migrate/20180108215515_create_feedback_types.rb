class CreateFeedbackTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :feedback_types do |t|
      t.references :bot, foreign_key: true
      t.string :name
      t.string :conflicts

      t.timestamps
    end
  end
end
