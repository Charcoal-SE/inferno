class PostType < ApplicationRecord
  has_many :bots, :through => :subscription

  enum post_type: [:posts, :comments, :edits, :reviews]
end
