require 'cgi'
require 'net/http'

class Chat
  include Singleton

  def initialize
    @cookies = []
    @bots = {
      'stackexchange' => ChatBot.new(ENV['CXUsername'], ENV['CXPassword'], default_server: 'stackexchange'),
      'stackoverflow' => ChatBot.new(ENV['CXUsername'], ENV['CXPassword'], default_server: 'stackoverflow'),
      'meta.stackexchange' => ChatBot.new(ENV['CXUsername'], ENV['CXPassword'], default_server: 'meta.stackexchange')
    }
  end

  def join_command_rooms
    @bots.each do |site, bot|
      Room.where(:site => site, :commands => true).each do |room|
        bot.add_hook room.room_id, 'message' do |msg|
          process_message msg, room
        end
      end
    end
  end

  def process_message(msg, room)
  end

  def send_msg(msg, site, room_id, bot)
    cookie = @cookies[bot.id]

    if !cookie
      cookie = Net::HTTP.get(bot.auth_route).body
      @cookies[bot.id] = cookie
    end

    request = Net::HTTP::Post.new("/chats/#{room_id}/messages/new")
    request['Cookie'] = "sechatusr=#{CGI.encode cookie}"

    Net::HTTP.start("chat.#{site}.com", 443) do |http|
      http.request(request)
    end
  end
end