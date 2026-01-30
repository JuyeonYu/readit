class MessagesController < ApplicationController
  before_action :require_login

  def new
    @message = current_user.messages.build
  end

  def create
    @message = current_user.messages.build(message_params)
    @message.valid? # Trigger validation
    # T04에서 저장 로직 구현 예정
    render :new, status: :unprocessable_entity
  end

  private

  def message_params
    params.require(:message).permit(:content, :password, :max_read_count, :expires_at)
  end
end
