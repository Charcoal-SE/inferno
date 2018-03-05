class CreatePostTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :post_types do |t|
      t.string :name
      t.string :ws
      t.string :route
      t.integer :allocation

      t.timestamps
    end
  end
end
