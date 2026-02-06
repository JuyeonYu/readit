class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  before_action :set_locale

  helper_method :current_user, :logged_in?

  private

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
  end

  def extract_locale
    # Priority: params > session > Accept-Language header > default
    locale = params[:locale]&.to_sym ||
             session[:locale]&.to_sym ||
             locale_from_accept_language

    locale if I18n.available_locales.include?(locale)
  end

  def locale_from_accept_language
    return nil unless request.env["HTTP_ACCEPT_LANGUAGE"]

    accepted_languages = request.env["HTTP_ACCEPT_LANGUAGE"]
      .split(",")
      .map { |lang| lang.split(";").first.strip.split("-").first.downcase.to_sym }

    (accepted_languages & I18n.available_locales).first
  end

  def set_navigation_data
    return unless logged_in?

    @nav_is_free_plan = current_user.free?
    if @nav_is_free_plan
      @nav_messages_this_month = current_user.messages_this_month
      @nav_message_limit = current_user.message_limit
      @nav_usage_percentage = [(@nav_messages_this_month.to_f / @nav_message_limit) * 100, 100].min.round
      @nav_resets_at = Time.current.next_month.beginning_of_month
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
