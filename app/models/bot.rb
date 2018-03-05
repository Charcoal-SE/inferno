class Bot < ApplicationRecord
  belongs_to :user

  has_many :commands
  has_many :feedback_types
  has_many :subscriptions
end
