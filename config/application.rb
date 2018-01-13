require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/chat'
require_relative '../lib/fetcher'

module Inferno
  def self.start_fetcher
    ppid = redis.getset("thread_ppid", Process.ppid)

    if !ppid || ppid.to_i != Process.ppid
      Chat.instance.join_rooms

      Thread.new do
        Fetcher.instance.run
      end
    end
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end

if defined?(Rails::Server)
  config.after_initialize do
    Inferno::start_fetcher
  end
end