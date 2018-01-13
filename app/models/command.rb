class Command < ApplicationRecord
  belongs_to :bot

  enum command_types: [:static, :local, :remote_get, :remote_post]
end
