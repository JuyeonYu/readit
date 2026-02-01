class NotificationsController < ApplicationController
  before_action :require_login

  def index
    @notifications = current_user.notifications
      .includes(:message)
      .order(created_at: :desc)
  end
end
