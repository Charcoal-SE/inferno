require 'set'
require 'socket'

class Fetcher
  include Singleton

  def run
    @current_ppm = 0
    @pending_ppm = 0

    ppm_window = []

    uri = URI.parse(self.url)

    @sock = TCPSocket.new(uri.host, 443)
    @driver = WebSocket::Driver.client(self)

    @driver.on(:open) { |_| 
      @driver.write("155-questions-active")
      #@driver.write("1-review-dashboard-update")
    }

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
    site = post['siteBaseHostAddress']

    if id == 3122 && site == 'meta.stackexchange.com'
      return
    end

    key = site + '-posts'

    redis.rpush(key, id)
    @pending_ppm += 1

    if redis.llen(key) > @current_ppm / (PostTypes.find(:posts).quota / 1440)
      posts = Set.new redis.lrange(key, 0, -1)
      redis.del(key)

      site = Site.find_or_create_by(:name => name)

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

      Parallel.each(posts, &:fetch_post)
    end
  end

  def fetch_post(id)
  end
end
