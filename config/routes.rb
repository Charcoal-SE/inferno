Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post 'bots/create', :to => 'bot#create'
  post 'bots/update_json', :to => 'bot#update_json'
end