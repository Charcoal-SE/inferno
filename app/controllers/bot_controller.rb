class BotController < ApplicationController
  before_action :authenticate_user!, only: [:create]
  before_action :check_bot, except: [:create]

  skip_before_action :verify_authenticity_token

  public

  def create
    name = params[:name]

    if !name || Bot.exists?(:name => name)
      render :plain => "Bot with name exists", :status => 400
    end

    bot = Bot.create(:user => current_user, :name => name, :token => SecureRandom.base64)

    config = request.body.read

    if config
      config = JSON.parse config

      begin
        update_from_config(bot, config)
      rescue RuntimeError => e
        render :plain => e.to_s, :status => 400
      rescue ActiveRecord::ActiveRecordError => e
        render :plain => "DB error", :status => 500
      else
        render :plain => "Bot created with config", :status => 200
      end
    else
      render :plain => "Empty bot created", :status => 200
    end
  end

  def update_json
    config = JSON.parse request.body.read

    if !config
      render :plain => "Missing config", :status => 400
    end

    begin
      update_from_config(@bot, config)
    rescue RuntimeError => e
      render :plain => e.to_s, :status => 400
    rescue ActiveRecord::ActiveRecordError => e
      render :plain => "DB error", :status => 500
    else
      render :plain => "Bot created with config", :status => 200
    end
  end

  private

  def update_from_config(bot, config)
    ActiveRecord::Base.transaction do
      bot.auth_route = config['auth_route']
      bot.save!

      types = config['types']

      if !types
        raise 'No post types specified'
      end

      Subscription.where(:bot => bot).delete_all

      types.each do |type_name, params|
        type = PostType.find_by(:name => type_name)

        if !type.present?
          raise "Unknown post type #{type_name}"
        end

        sites = params['sites']
        subscription = nil

        if !sites
          subscription = Subscription.create!(:bot => bot, :post_type => type, :site => Site.find_or_create_by(:name => 'stackoverflow.com'))
        elsif sites == '*'
          subscription = Subscription.create!(:bot => bot, :post_type => type, :all_sites => true)
        else
          sites.each do |site|
            subscription = Subscription.create!(:bot => bot, :post_type => type, :site => Site.find_or_create_by(:name => site))
          end
        end

        query = params['query']

        if !query
          raise "No query specified for #{type_name}"
        end

        method = Subscription.request_methods[query[:method] || 'POST']

        if !method
          raise "Invalid method for #{type_name} (POST, GET or WS)"
        end

        subscription.request_method = method

        if method != 'WS'
          route = query['route']

          if !route
            raise "No route specified for #{type_name}"
          end

          subscription.route = route
        end

        response = query['response']

        if !response
          raise "Missing response section for #{type_name}"
        end

        response_key = response['key']

        if !response_key
          raise "Need to specify a key in the response for #{type_name} classification"
        end

        key_type = Subscription.key_types[response['type'] || 'switch']

        if !key_type
          raise "Invalid key type for #{type_name} (switch for bool, score for float)"
        end

        subscription.spam_key = response_key
        subscription.key_type = key_type

        if type_name == 'questions'
          answers_key = response['answer_key']

          if !answer_key
            raise 'Need to specify answer classification key for questions post type'
          end

          subscription.answer_key = answer_key
        end

        if key_type == 'score'
          min_score = response['minimum']

          if !min_score
            raise "Need to specify minimum score for reporting #{type_name}"
          end

          subscription.min_score = min_score
        end

        templates = query['templates']

        if !templates
          raise "No report templates specified for #{type_name}"
        end

        chat_template = templates['chat']

        if !chat_template
          raise "Need a chat template for #{type_name}"
        end

        subscription.chat_template = chat_template
        subscription.web_template = templates['web']

        subscription.save!
      end

      feedbacks = config['feedback_types']

      if feedbacks
        feedbacks.each do |name, feedback|
          type = FeedbackType.types[feedback['type']]

          if !type
            raise "Missing type for feedback #{name}"
          end

          aliases = [FeedbackType.find_or_create_by!(:bot => bot, :name => name)]

          if feedback['aliases']
            aliases.concat feedback['aliases'].map do |name| FeedbackType.find_or_create_by!(:bot => bot, :name => name) end
          end

          aliases.each do |record|
            feedback.update(:type => type, :blacklist => feedback['blacklist'] || false, :icon => feedback['icon'])
            feedback.save!
          end
        end
      end

      commands = config['commands']

      if commands
        commands.each do |primary_name, command|
          type = Command.types[command['type']]

          if !type
            return :text => "Invalid command type for #{primary_name} (static, local, remote)", :status => 400
          end

          data = command['data']

          if !data
            return :text => "Missing data for #{primary_name}", :status => 400
          end

          reply = command['reply'] || false
          privileged = command['privileged'] || false

          min_arity = command['min'] || 0
          max_arity = command['max'] || 0

          aliases = [Command.find_or_create_by!(:bot => bot, :name => primary_name)]

          if command['aliases']
            aliases.concat command['aliases'].map do |name| Command.find_or_create_by!(:bot => bot, :name => name) end
          end

          aliases.each do |cmd|
            cmd.update(:type => type, :data => data, :reply => reply, :privileged => privileged, :min => min_arity, :max => max_arity)
            cmd.save!
          end
        end
      end

      rooms = config[:rooms]

      if rooms
        rooms.each do |id, room|
          # didn't finish this yet
        end
      end

      # improvement: tell what's been modified
      $redis.set('reload_subscriptions', 1)
      $redis.set(bot.id.to_s, 1)
    end

    return :text => "Bot created with config", :status => 200
  end
end
