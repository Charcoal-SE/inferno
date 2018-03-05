require 'cgi'
require 'net/http'

class Chat
  include Singleton

  Servers = ['stackexchange', 'stackoverflow', 'meta.stackexchange']

  def initialize
    @bots = {}

    @bots[-1] = ChatBot.new(ENV['CXUsername'], ENV['CXPassword'])
  end

  def join_command_rooms
    @bots[-1].login Servers

    #Servers.each do |site|
    #  Room.where(:site => site, :commands => true).each do |room|
    #    @bot.join_room room.room_id, :server => site
    #
    #    @bot.add_hook room.room_id, 'message', :server => site do |msg|
    #      room.bots.each do |bot|
    #        Bot.bot_interfaces[bot.id].chat(msg)
    #      end
    #    end
    #  end
    #end
  end

  def process_message(msg, room)
  end

  def send_msg(msg, site, room_id, bot)
    chat = @bots[bot.id]

    if !chat
      if !bot.auth_route.present?
        chat = @bots[-1]
      else
        chat = ChatBot.new
        chat.login JSON.parse(Net::HTTP.get(bot.auth_route).body)

        @bots[bot.id] = chat
      end
    end

    chat.say msg, room_id, :server => site
  end
end
