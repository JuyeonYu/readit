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

    # T08에서 읽기 처리 구현 예정
    render :show
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
