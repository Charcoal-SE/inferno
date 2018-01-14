class ApplicationController < ActionController::Base
  protected

  def get_bot(request)
    token = request[:token]

    if token
      return Bot.find_by(:token => token)
    else
      user = current_user

      if !user
        return nil
      end

      return Bot.find_by(:id => request[:id], :user => user)
    end
  end
end
