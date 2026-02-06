class NotificationsController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data

  def index
    @notifications = current_user.notifications
      .includes(:message)
      .order(created_at: :desc)
  end
end
