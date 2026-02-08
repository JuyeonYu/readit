class MessagesController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data, only: [:share]
  before_action :check_message_limit, only: %i[new create]
  before_action :set_usage_stats, only: [ :new, :edit ]
  before_action :set_message, only: %i[edit update destroy toggle_notify]

  def new
    @message = current_user.messages.build
  end

  def create
    @message = current_user.messages.build(message_params)

    # Handle expires_in dropdown (days from now) - Pro only
    if params.dig(:message, :expires_in).present? && !current_user.free?
      days = params[:message][:expires_in].to_i
      @message.expires_at = days.days.from_now if days > 0
    end

    # Clear Pro features for free users
    if current_user.free?
      @message.expires_at = nil
      @message.max_read_count = nil
    end

    if @message.save
      # Increment monthly message count for free users
      current_user.increment_monthly_message_count! if current_user.free?

      # Send limit warning/reached emails if applicable
      OnboardingService.new(current_user).after_message_created

      redirect_to share_message_path(@message.token)
    else
      set_usage_stats
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Handle expires_in dropdown (days from now) - Pro only
    if !current_user.free?
      if params.dig(:message, :expires_in).present?
        days = params[:message][:expires_in].to_i
        @message.expires_at = days > 0 ? days.days.from_now : nil
      elsif params.dig(:message, :expires_in) == ""
        @message.expires_at = nil
      end
    end

    # Filter out Pro features for free users
    filtered_params = message_params
    if current_user.free?
      filtered_params = filtered_params.except(:max_read_count, :expires_at)
    end

    if @message.update(filtered_params)
      redirect_to share_message_path(@message.token), notice: t('flash.messages.updated')
    else
      set_usage_stats
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @message.destroy
    redirect_to dashboard_path, notice: t('flash.messages.deleted')
  end

  def toggle_notify
    @message.update(notify_on_read: !@message.notify_on_read)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("notify-toggle", partial: "messages/notify_toggle", locals: { message: @message }) }
      format.html { redirect_to share_message_path(@message.token) }
    end
  end

  def share
    @message = current_user.messages.includes(:read_events).find_by!(token: params[:token])
    result = @message.grouped_reads(limit: 20)
    @grouped_reads = result[:viewers]
    @total_viewers = result[:total_viewers]
    @has_more_viewers = result[:has_more]
  end

  private

  def set_message
    @message = current_user.messages.find_by!(token: params[:token])
  end

  def message_params
    params.require(:message).permit(:title, :content, :password, :max_read_count, :expires_at, :notify_on_read)
  end

  def set_usage_stats
    @message_limit = current_user.message_limit
    @messages_this_month = current_user.messages_this_month
    @is_free_plan = current_user.free?
    @usage_percentage = @is_free_plan ? [ (@messages_this_month.to_f / @message_limit) * 100, 100 ].min.round : 0
  end

  def check_message_limit
    return unless current_user.free?
    return unless current_user.at_message_limit?

    redirect_to dashboard_path, alert: t('flash.messages.limit_reached')
  end
end
