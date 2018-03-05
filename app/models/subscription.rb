require 'shellwords'

class Subscription < ApplicationRecord
  belongs_to :bot
  belongs_to :post_type
  belongs_to :site

  enum :request_method => [:POST, :GET, :WS]
  enum :key_type => [:switch, :score]

  cattr_accessor :interfaces
  Subscription.interfaces = {}

  def build_interface
    bot = self.bot
    interface = Subscription.interfaces[self.id]

    if !interface
      interface = Object.new
      Subscription.interfaces[self.id] = interface
    end

    post_func = "->(api_str, api_hash) do "

    if self.request_method == 'POST' then
      post_func << "http = EM::HttpRequest.new('#{Shellwords.shellescape(self.route)}').post(:body => api_str); http.callback do "
    else
      post_func << "http = EM::HttpRequest.new('#{Shellwords.shellescape(self.route)}').get(:items => api_str); http.callback do "
    end

    post_func << "res = JSON.parse(http.response)['items']; res.each_with_index do |item, i| "

    key = make_key(self.spam_key)
    do_report = "if "

    case self.key_type
    when 'switch'
      do_report << "item#{key} then"
    when 'score'
      do_report << "item#{key} > #{self.min_score} then"
    end

    do_report << " Chat.instance.send_msg(api_hash['items'][i]['link'], 'stackexchange', 30332, bot) end"

    post_func << do_report

    if self.answer_key
      post_func << ";item#{make_key(self.answer_key)}.each_with_index do |item, i| #{do_report} end"
    end

    post_func << " end end end"

    interface.define_singleton_method(:api, eval(post_func))

    # Closure keeps these from being GC'd, so get rid of them to avoid a leak
    interface = nil
    post_func = nil
    do_report = nil
    spam_key = nil
  end

  private

  def make_key(string)
    output = ""

    string.split(".").each do |prop|
      output << "['#{Shellwords.shellescape(prop)}']"
    end

    return output
  end
end
