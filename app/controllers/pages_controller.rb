class PagesController < ApplicationController
  before_action :set_navigation_data, only: [:home]

  def home
    if logged_in?
      @pagy, @messages = pagy(current_user.messages.order(created_at: :desc))
    end
  end

  def privacy
  end

  def terms
  end

  def refund
  end
end
