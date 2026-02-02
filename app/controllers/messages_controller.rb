class MessagesController < ApplicationController
  before_action :require_login

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
      redirect_to share_message_path(@message.token)
    else
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
end
