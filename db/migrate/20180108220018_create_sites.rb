class CreateSites < ActiveRecord::Migration[5.2]
  def change
    create_table :sites do |t|
      t.string :domain
      t.integer :last_scanned

      t.timestamps
    end
  end
end
