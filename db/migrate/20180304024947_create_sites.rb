class CreateSites < ActiveRecord::Migration[5.2]
  def change
    create_table :sites do |t|
      t.string :name
      t.integer :last_scanned
      t.integer :se_id

      t.timestamps
    end
  end
end
