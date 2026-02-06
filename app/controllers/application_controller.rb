class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  helper_method :current_user, :logged_in?

  private

  def set_navigation_data
    return unless logged_in?

    @nav_is_free_plan = current_user.free?
    if @nav_is_free_plan
      @nav_messages_this_month = current_user.messages.where("created_at >= ?", Time.current.beginning_of_month).count
      @nav_message_limit = current_user.message_limit
      @nav_usage_percentage = [(@nav_messages_this_month.to_f / @nav_message_limit) * 100, 100].min.round
    end
  end

  def render_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      session[:return_to] = request.fullpath
      redirect_to login_path, alert: I18n.t("errors.login_required")
    end
  end
end
