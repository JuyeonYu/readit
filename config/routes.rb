Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  # Authentication
  get "login" => "sessions#new"
  post "login" => "sessions#create"
  get "login/sent" => "sessions#sent", as: :login_sent
  get "login/verify/:token" => "sessions#verify", as: :verify_login
  delete "logout" => "sessions#destroy"

  # Messages
  resources :messages, only: %i[new create]
  get "share/:token" => "messages#share", as: :share_message

  # Notifications
  resources :notifications, only: %i[index]

  # Reads
  get "read/:token" => "reads#show", as: :read_message
  post "read/:token" => "reads#create"
  get "expired" => "reads#expired", as: :expired_message
end
