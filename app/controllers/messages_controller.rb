class MessagesController < ApplicationController
  def new
    @message = Message.new
  end

  def create
    @message = Message.new(message_params)
    @message.valid? # Trigger validation
    # T04에서 저장 로직 구현 예정
    render :new, status: :unprocessable_entity
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
