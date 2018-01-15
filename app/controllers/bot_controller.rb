class BotController < ApplicationController
  before_action :authenticate_user!, only: [:create]
  before_action :check_bot, except: [:create]

  public

  def create
    name = params[:name]

    if !name || Bot.exists?(:name => name)
      render :text => "Bot with name exists", :status => 400
    end

    bot = Bot.create(:user => current_user, :name => name, :token => SecureRandom.base64)

    config = JSON.parse request.body.read

    if !config
      render update_from_config(bot, config)
    else
      render :text => "Empty bot created", :status => 200
    end
  end

  def update_json
    config = JSON.parse request.body.read

    if !config
      render :text => "Missing config", :status => 400
    end

    render update_from_config(@bot, config)
  end

  private

  def update_from_config(bot, config)
    types = config[:types]

    if !types
      return :text => "No post types specified", :status => 400
    end

    types.each do |type|
      type_sym = PostType.post_types[type]

      if !type_sym
        return :text => "Unknown post type #{type}", :status => 400
      end

      Subscription.find_or_create_by(:bot => bot, :post_type => type_sym)
    end

    query = config[:query]

    if !query
      return :text => "No query specified", :status => 400
    end

    method = Bot.scan_methods[query[:method] || "POST"]

    if !method
      return :text => "Invalid method (POST, GET or WS)", :status => 400
    end

    bot.scan_method = method

    if method != "WS"
      route = query[:route]

      if !route
        return :text => "No route specified", :status => 400
      end

      bot.route = route
    end

    response = config[:response]

    if !response
      return :text => "Missing response section", :status => 400
    end

    response_key = response[:key]

    if !response_key
      return :text => "Need to specify a key in the response for classification", :status => 400
    end

    key_type = Bot.key_types[response[:type] || "switch"]

    if !key_type
      return :text => "Invalid key type (switch for bool, score for float)", :status => 400
    end

    bot.spam_key = response_key
    bot.key_type = key_type

    if config[:feedback_types]
      config[:feedback_types].each do |name, feedback|
        if feedback[:conflicts_with]
          feedback[:conflicts_with].each do |conflict|
            FeedbackType.find_or_create_by(:bot => bot, :name => name).update(:conflicts => conflict)
          end
        end
      end
    end

    if config[:commands]
      config[:commands].each do |primary_name, command|
        names = [primary_name]

        if command[:aliases]
          names.concat command[:aliases]
        end

        names.each do |name|
          type = Command.command_types[command[:type]]

          if !type
            return :text => "Invalid command type for #{name} (static, local, remote_get or remote_post)", :status => 400
          end

          data = command[:data]

          if !data
            return :text => "Missing data for #{name}", :status => 400
          end

          min_arity = command[:min] || 0
          max_arity = command[:max] || 0

          Command.find_or_create_by(:name => name).update(:type => type, :data => data, :min => min_arity, :max => max_arity)
        end
      end
    end

    rooms = config[:rooms]

    config[:rooms].each do |id, room|
    end

    bot.save!

    redis.setbit("api_rebuild", bot.id, 1)
    redis.setbit("cmd_rebuild", bot.id, 1)

    return :text => "Bot created with config", :status => 200
  end
end
