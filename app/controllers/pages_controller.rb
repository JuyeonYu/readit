class PagesController < ApplicationController
  def home
    @messages = current_user.messages.order(created_at: :desc) if logged_in?
  end

  def privacy
  end

  def terms
  end

  def refund
  end
end
