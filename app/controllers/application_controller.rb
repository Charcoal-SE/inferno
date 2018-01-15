class ApplicationController < ActionController::Base
  protected

  def check_bot
    token = params[:token]

    if token
      @bot = Bot.find_by(:token => token)
    else
      user = current_user

      if !user
        render :text => "Sign in or use secret token", :status => 403
      end

      @bot = Bot.find_by(:id => params[:id], :user => user)
    end

    if !@bot
      render :text => "No such bot", :status => 404
    end
  end
end
