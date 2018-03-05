require 'set'

class PostStats
  private
  attr_accessor :desired_cpm, :current_ppm, :pending_ppm, :ppm_window

  public
  cattr_accessor :post_types
  PostStats.post_types = {}

  def initialize(type)
    update_allocation(type.allocation)

    @current_ppm = 0
    @pending_ppm = 0
    @ppm_window = []

    PostStats.post_types[type.id] = self
  end

  def update_allocation(new_allocation)
    @desired_cpm = new_allocation / 1440
  end

  def add_post
    @pending_ppm += 1
  end

  def rollover
    if @ppm_window.size >= 60
      @ppm_window.unshift
    end

    @ppm_window.push @pending_ppm

    @current_ppm = @ppm_window.sum / @ppm_window.size
    @pending_ppm = 0
  end

  def threshold
    return @current_ppm / @desired_cpm
  end

  def self.rollover
    PostStats.post_types.each_value(&:rollover)
  end
end

class Fetcher < EventMachine::Connection
  cattr_accessor :fetcher

  Filter = '!)k_3iHEfnikRI4A..IXrGIwdpOt2bdTX268heIMovWXJwZNk.BEPI*R(8AbEt)AkH'
  ApiKey = 'IAkbitmze4B8KpacUfLqkw(('

  def self.run
    Thread.new do
      EM.run do
        EM.connect('qa.sockets.stackexchange.com', 443, Fetcher)
      end
    end
  end

  def connection_completed
    start_tls

    @backoff = 0
    @quota = 0
    @api_queue = EM::Queue.new

    @actions = {}
    @pollers = []
    @driver = WebSocket::Driver.client(self)

    @driver.on(:open, &method(:reload_subscriptions))
    @driver.on(:message, &method(:on_msg))
    @api_queue.pop(&method(:api_fetch))

    EM.add_periodic_timer(60) do
      PostStats.rollover

      if $redis.getset('reload_subscriptions', 0) == '1'
        reload_subscriptions(nil)
      end
    end

    @driver.start
    Fetcher.fetcher = self
  end

  def url
    return 'wss://qa.sockets.stackexchange.com'
  end

  def write(data)
    send_data(data)
  end

  def receive_data(data)
    @driver.parse(data)
  end

  def reload_subscriptions(_)
    @pollers.each(&:cancel)

    old_actions = []

    @actions.each_key do |action|
      @actions[action][2] = []
      old_actions.push action
    end

    Subscription.all.each do |subscription|
      type = subscription.post_type

      if type.ws
        if type.per_site
          if subscription.all_sites.present?
            Site.all.each do |site|
              register_ws_action(site.se_id, subscription)
            end
          else
            register_ws_action(subscription.site.se_id, subscription)
          end
        else
          register_ws_action(155, subscription)
        end
      else
        start_poller(subscription)
      end
    end

    old_actions.each do |action|
      if @actions[action][2] == []
        @driver.text "-#{action}"
        @actions.delete action
      end
    end

    PostStats.post_types.each do |id, stats|
      stats.update_allocation PostType.find(id).allocation
    end
  end

  def start_poller(subscription)
    bot_id = subscription.bot.id.to_s
    site_name = subscription.site.name
    route = subscription.post_type.route

    last_date = Time.now.to_i
    period = 86400 / subscription.post_type.allocation
    interface_id = subscription.id

    @pollers << EM.add_periodic_timer(period) do
      @api_queue.push([route, site_name, "?order=desc&fromdate=#{last_date}&sort=creation&pagesize=100", ->(data, parsed) do
        last_date = parsed["items"][-1]["creation_date"]

        if !Subscription.interfaces.has_key?(interface_id) || $redis.getset(bot_id, 0) == '1'
          EM.defer(->() do subscription.build_interface end, ->(_) do
            Subscription.interfaces[interface_id].api(data, parsed)
          end)
        else
          Subscription.interfaces[interface_id].api(data, parsed)
        end
      end])
    end
  end

  def register_ws_action(site_id, subscription)
    action = "#{site_id}-#{subscription.post_type.ws}"
    type = subscription.post_type

    route = type.route

    if !PostStats.post_types.has_key?(type.id)
      PostStats.new type
    end

    stats = PostStats.post_types[type.id]

    if !@actions.has_key? action
      @driver.text action
      @actions[action] = [route, stats, []]
    end

    bot_id = subscription.bot.id.to_s
    interface_id = subscription.id

    @actions[action][2].push [bot_id, interface_id, subscription]
  end

  def on_msg(post)
    post = JSON.parse(post.data)

    action = post['action']

    if action == 'hb'
      return @driver.text('hb')
    else
      action_data = @actions[action]

      if action_data
        data = JSON.parse(post['data'])
        enqueue(data, action_data)
      end
    end
  end

  def enqueue(data, action_data)
    route, stats, callbacks = action_data

    id = post['id']
    site_name = post['siteBaseHostAddress']

    if id == 3122 && site_name == 'meta.stackexchange.com'
      return
    end

    key = site_name + '-posts'

    $redis.sadd(key, id)
    stats.add_post

    if $redis.scard(key) > stats.threshold
      posts = Set.new $redis.smembers(key)
      $redis.del(key)

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

      @api_queue.push([route, site_name, posts.join(';'), ->(items, parsed) do
        items.chop!

        callbacks.each do |callback|
          bot_id, interface_id, handle = callback

          if !Subscription.interfaces.has_key?(interface_id) || $redis.getset(bot_id, 0) == '1'
            EM.defer(->() do handle.build_interface end, ->(_) do
              Subscription.interfaces[interface_id].api(post, parsed)
            end)
          else
            Subscription.interfaces[interface_id].api(post, parsed)
          end
        end
      end])
    end
  end

  def api_fetch(item)
    remaining_backoff = @backoff - Time.now.to_i

    if remaining_backoff > 0 then
      EM.add_timer(remaining_backoff + 1) do api_fetch(item) end
      return
    end

    route, site, data, callback = item

    request_uri = "https://api.stackexchange.com/2.2#{route}/#{data}"
    http = EM::HttpRequest.new(request_uri).get :query => {:site => site, :filter => Filter, :key => ApiKey}

    http.callback do
      result = http.response
      parsed = JSON.parse result

      if parsed['backoff']
        new_backoff = Time.now.to_i + parsed['backoff']

        if new_backoff > @backoff
          @backoff = new_backoff
        end
      end

      if parsed['error_message']
        Rails.logger.info "API error for #{route}, #{data}: #{parsed['error_message']}"

        if parsed['error_id'] == 502
          @backoff = Time.now.to_i + 11
        end
      end

      if parsed['quota_remaining']
        @quota = parsed['quota_remaining']
      end

      if parsed['items']&.present?
        callback.call(result, parsed)
      end

      @api_queue.pop(&method(:api_fetch))
    end
  end
end
