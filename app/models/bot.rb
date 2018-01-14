require 'shellwords'

class Bot < ApplicationRecord
  belongs_to :user

  has_many :commands
  has_many :feedback_types
  has_many :subscriptions

  enum scan_method: [:POST, :GET, :WS]
  enum key_type: [:switch, :score]

  cattr_accessor :bot_interfaces
  Bot.bot_interfaces = []

  class BotInterface
    attr_accessor :api, :cmd
  end

  def build_interface
    interface = Bot.bot_interfaces[self.id]

    if !interface
      interface = BotInterface.new
      Bot.bot_interfaces[self.id] = interface
    end

    route_url = URI::Parse(self.route)

    host = route_url.host
    port = route_url.port

    if self.scan_method == :POST
      request_obj = Net::HTTP::Post.new(route_url.request_uri)
    else
      request_obj = NET::HTTP::Get.new(route_url.request_uri)
    end

    post_func = "function(api_response)res=JSON.parse((Net::HTTP.start(host, port)do|http|http.request(request_obj)end).body);"

    post_func << "classification=res"

    self.spam_key.split(".").each do |prop|
      post_func << "['#{Shellwords.shellescape(prop)}']'"
    end

    #if self.key_type == :switch
    #  
    #end

    post_func << "end"
    interface.api = eval(post_func)

    # do cmd
  end
end
