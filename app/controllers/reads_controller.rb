class ReadsController < ApplicationController
  before_action :set_message, only: %i[show create]
  before_action :check_readable, only: %i[show create]

  def show
  end

  def create
    if @message.password_digest.present?
      unless @message.authenticate(params[:password])
        flash.now[:alert] = "비밀번호가 올바르지 않습니다"
        return render :show, status: :unprocessable_entity
      end
    end

    viewer_token = cookies.signed[:viewer_token] ||= SecureRandom.hex(32)

    result = ReadMessageService.call(
      @message,
      viewer_token_hash: Digest::SHA256.hexdigest(viewer_token),
      user_agent: request.user_agent
    )

    if result.success?
      render :content
    else
      redirect_to expired_message_path, alert: result.error
    end
  end

  def expired
  end

  private

  def set_message
    @message = Message.find_by!(token: params[:token])
  end

  def check_readable
    redirect_to expired_message_path unless @message.readable?
  end
end
