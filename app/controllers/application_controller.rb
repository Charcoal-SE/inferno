class ApplicationController < ActionController::Base
  protected

  def get_bot(request)
    token = params[:token]

    if token
      return Bot.find_by(:token => token)
    else
      user = current_user
      id = params[:id]

      return Bot.find_by(:id => id, :user => user)
    end
  end
end
