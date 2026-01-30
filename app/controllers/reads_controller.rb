class ReadsController < ApplicationController
  def show
    @message = Message.find_by!(token: params[:token])

    unless @message.readable?
      redirect_to expired_message_path
    end
  end

  def expired
  end
end
