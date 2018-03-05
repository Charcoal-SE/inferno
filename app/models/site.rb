require 'net/http'

class Site < ApplicationRecord
  has_many :subscriptions
  after_create :fetch_metadata

  def fetch_metadata
    request = Net::HTTP::Get.new('/')
    response = Net::HTTP.start(self.name, 443, :use_ssl => true) do |http| http.request(request) end

    body = Nokogiri::HTML response.body

    self.se_id = body.css('a.current-site-link.site-link.js-gps-track').attr('data-id').value.to_i
    self.save!
  end
end
