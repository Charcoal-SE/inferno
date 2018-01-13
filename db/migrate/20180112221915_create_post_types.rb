class CreatePostTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :post_types do |t|
      t.string :name
      t.integer :quota

      t.timestamps
    end

    PostType.create :id => :posts, :name => 'Posts'
    PostType.create :id => :comments, :name => 'Comments'
    PostType.create :id => :edits, :name => 'Edits'
    PostType.create :id => :reviews, :name => 'Reviews'
  end
end
