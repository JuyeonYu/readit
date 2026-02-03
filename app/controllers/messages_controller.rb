class MessagesController < ApplicationController
  before_action :require_login
  before_action :check_message_limit, only: %i[new create]
  before_action :set_usage_stats, only: [:new]

  def new
    @message = current_user.messages.build
  end

  def create
    @message = current_user.messages.build(message_params)

    # Handle expires_in dropdown (days from now)
    if params.dig(:message, :expires_in).present?
      days = params[:message][:expires_in].to_i
      @message.expires_at = days.days.from_now if days > 0
    end

    if @message.save
      # Send limit warning/reached emails if applicable
      OnboardingService.new(current_user).after_message_created

      redirect_to share_message_path(@message.token)
    else
      set_usage_stats
      render :new, status: :unprocessable_entity
    end
  end

  def share
    @message = current_user.messages.includes(:read_events).find_by!(token: params[:token])
    @grouped_reads = @message.read_events
      .group_by(&:viewer_token_hash)
      .transform_values { |events| events.sort_by(&:read_at) }
      .sort_by { |_, events| events.first.read_at }
      .reverse
  end

  private

  def message_params
    params.require(:message).permit(:title, :content, :password, :max_read_count, :expires_at)
  end

  def set_usage_stats
    @message_limit = current_user.message_limit
    @messages_this_month = current_user.messages_this_month
    @is_free_plan = current_user.free?
    @usage_percentage = @is_free_plan ? [(@messages_this_month.to_f / @message_limit) * 100, 100].min.round : 0
  end

  def check_message_limit
    return unless current_user.free?
    return unless current_user.at_message_limit?

    redirect_to dashboard_path, alert: "You've reached your monthly message limit. Upgrade to Pro for unlimited messages."
  end
end
