require 'cgi'
require 'net/http'

class Chat
  include Singleton

  Servers = ['stackexchange', 'stackoverflow', 'meta.stackexchange']

  def initialize
    @sessions = []
    @bot = ChatBot.new(ENV['CXUsername'], ENV['CXPassword'])
  end

  def join_command_rooms
    @bot.login(Servers)

    Servers.each do |site|
      Room.where(:site => site, :commands => true).each do |room|
        @bot.join_room room.room_id, server: site

        @bot.add_hook room.room_id, 'message', server: site do |msg|
          process_message msg, room
        end
      end
    end
  end

  def process_message(msg, room)
  end

  def send_msg(msg, site, room_id, bot)
    session = @sessions[bot.id]

    if !session
      session = JSON.parse Net::HTTP.get(bot.auth_route).body
      @session[bot.id] = session
    end

    creds = session[site]

    request = Net::HTTP::Post.new("/chats/#{room_id}/messages/new?fkey=#{URI.encode creds['fkey']}&text=#{URI.encode msg}")
    request['Cookie'] = "sechatusr=#{CGI.encode creds['cookie']}"

    Net::HTTP.start("chat.#{site}.com", 443) do |http|
      http.request(request)
    end
  end
end
