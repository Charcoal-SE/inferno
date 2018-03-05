class Command < ApplicationRecord
  belongs_to :bot

  enum :type => [:static, :local, :remote]
end
