class MessagesController < ApplicationController
  before_action :require_login

  def new
    @message = current_user.messages.build
  end

  def create
    @message = current_user.messages.build(message_params)

    if @message.save
      redirect_to share_message_path(@message.token)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def share
    @message = current_user.messages.find_by!(token: params[:token])
  end

  private

  def message_params
    params.require(:message).permit(:content, :password, :max_read_count, :expires_at)
  end
end
