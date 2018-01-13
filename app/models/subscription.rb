class Subscription < ApplicationRecord
  belongs_to :bot
  belongs_to :post_type
end
