class PostType < ApplicationRecord
  has_many :bots, :through => :subscription
end