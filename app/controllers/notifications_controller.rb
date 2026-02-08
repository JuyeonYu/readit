class NotificationsController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data

  def index
    @pagy, @notifications = pagy(
      current_user.notifications.includes(:message).order(created_at: :desc)
    )
  end
end
