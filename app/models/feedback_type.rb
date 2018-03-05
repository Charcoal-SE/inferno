class FeedbackType < ApplicationRecord
  belongs_to :bot

  enum :type => [:true, :neutral, :false]
end
