require 'set'
require 'socket'

class Fetcher
  include Singleton

  def run
    @backoff = 0
    @quota = 0

    @current_ppm = 0
    @pending_ppm = 0

    ppm_window = []

    uri = URI.parse(self.url)

    @sock = TCPSocket.new(uri.host, 443)
    @driver = WebSocket::Driver.client(self)

    @driver.on(:open) do |_| 
      @driver.write("155-questions-active")
      #@driver.write("1-review-dashboard-update")
    end

    @driver.on(:message, &method(:on_post))

    Thread.new do
      loop do
        sleep(60)

        if ppm_window.size >= 60
          ppm_wimdow.unshift
        end

        ppm_window.push pending_ppm

        @current_ppm = ppm_window.sum / ppm_window.size
        @pending_ppm = 0
      end
    end

    loop do
      @driver.parse(@sock.read(1))
    end
  end

  def url
    return 'wss://qa.sockets.stackexchange.com'
  end

  def write(data)
    @sock.write(data)
  end

  def on_post(post)
    post = JSON.parse(JSON.parse(post)['data'])

    id = post['id']
    site_name = post['siteBaseHostAddress']

    if id == 3122 && site_name == 'meta.stackexchange.com'
      return
    end

    key = site_name + '-posts'

    redis.sadd(key, id)
    @pending_ppm += 1

    if redis.scard(key) > @current_ppm / (PostTypes.find(:posts).quota / 1440)
      posts = Set.new redis.smembers(key)
      redis.del(key)

      site = Site.find_or_create_by(:name => site_name)

      current_max_id = posts.max
      previous_max_id = site.last_scanned

      if current_max_id > previous_max_id
        site.last_scanned = current_max_id
        site.save

        diff = current_max_id - previous_max_id - 1

        if diff > 100
          diff = 100
        end

        posts.union (current_max_id - diff .. current_max_id - 1)
      end

      items = fetch_posts(site_name, posts)

      if items then
        items = items[:-1]

        Subscriptions.where(:post_type => :posts).each do |subscription|
          bot = subscription.bot

          if redis.getset(bot.id.to_s, 0) == '1'
            bot.rebuild_interface
          end

          Bot.bot_interfaces[bot.id].api("#{items[:-1]},'token':'#{bot.token}'}")
        end
      end
    end
  end

  def fetch_posts(site, ids, json = false)
    remaining_backoff = @backoff - Time.now.to_i

    if @remaining_backoff > 0 then
      sleep(remaining_backoff + 1)
    end

    ids = ids.join ';'

    request_uri = "https://api.stackexchange.com/2.2/question/#{ids}?site=#{site}"
                  "&filter=!)E0g*ODaEZ(SgULQhYvCYbu09*ss(bKFdnTrGmGUxnqPptuHP&key=IAkbitmze4B8KpacUfLqkw(("

    result = Net::HTTP.get(request_uri)

    parsed = JSON.parse result

    if !parsed['items'] then
      logger.info "No items returned for #{ids}"
      return nil
    end

    if parsed['backoff'] then
      new_backoff = Time.now.to_i + parsed['backoff']

      if new_backoff > @backoff then
        @backoff = new_backoff
      end
    end

    if parsed['error_msg'] then
      logger.info "API error for #{ids}: #{parsed['error_msg']}"

      if parsed['error_id'] == 502 then
        @backoff = Time.now.to_i + 11
      end
    end

    if parsed['quota_remaining'] then
      @quota = parsed['quota_remaining']
    end

    return json ? parsed : result
  end
end
