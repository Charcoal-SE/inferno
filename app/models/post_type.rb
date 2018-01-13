class PostType < ApplicationRecord
  has_many :subscription

  enum post_type: [:posts, :comments, :edits, :reviews]
end
