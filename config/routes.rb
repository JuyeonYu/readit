Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  # Legal pages
  get "privacy" => "pages#privacy", as: :privacy
  get "terms" => "pages#terms", as: :terms
  get "refund" => "pages#refund", as: :refund

  # Authentication
  get "login" => "sessions#new"
  post "login" => "sessions#create"
  get "login/sent" => "sessions#sent", as: :login_sent
  get "login/verify/:token" => "sessions#verify", as: :verify_login
  delete "logout" => "sessions#destroy"

  # Dashboard
  get "dashboard" => "dashboard#index", as: :dashboard
  get "dashboard/message/:token" => "dashboard#show", as: :dashboard_message

  # Pricing & Upgrade
  get "pricing" => "pricing#index", as: :pricing
  get "upgrade" => "pricing#index", as: :upgrade
  get "upgrade/monthly" => "checkout#monthly", as: :upgrade_monthly
  get "upgrade/yearly" => "checkout#yearly", as: :upgrade_yearly

  # Checkout
  post "checkout" => "checkout#create", as: :checkout
  get "checkout/success" => "checkout#success", as: :checkout_success
  get "checkout/cancel" => "checkout#cancel", as: :checkout_cancel

  # Billing management
  get "billing" => "billing#show", as: :billing
  post "billing/portal" => "billing#portal", as: :billing_portal
  patch "billing/webhook" => "billing#update_webhook", as: :update_webhook

  # Webhooks
  post "webhooks/lemon_squeezy" => "webhooks#lemon_squeezy"

  # Messages
  resources :messages, only: %i[new create edit update destroy], param: :token do
    member do
      patch :toggle_notify
    end
  end
  get "share/:token" => "messages#share", as: :share_message

  # Notifications
  resources :notifications, only: %i[index]

  # Reads
  get "read/:token" => "reads#show", as: :read_message
  post "read/:token" => "reads#create"
  patch "read/:token/reaction" => "reads#reaction", as: :message_reaction
  get "expired" => "reads#expired", as: :expired_message

  # Short URL for message reading (used in production/screenshots)
  get "m/:token" => "reads#show", as: :short_read_message
  post "m/:token" => "reads#create"
  patch "m/:token/reaction" => "reads#reaction"
end
