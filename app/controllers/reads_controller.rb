class ReadsController < ApplicationController
  before_action :set_message, only: %i[show create reaction]
  before_action :check_readable, only: %i[show create]

  def show
  end

  def create
    if @message.password_digest.present?
      unless @message.authenticate(params[:password])
        flash.now[:alert] = t('flash.reads.incorrect_password')
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
      @read_event = result.read_event
      render :content
    else
      redirect_to expired_message_path, alert: result.error
    end
  end

  def reaction
    viewer_token = cookies.signed[:viewer_token]
    return head :unauthorized unless viewer_token

    viewer_token_hash = Digest::SHA256.hexdigest(viewer_token)
    read_event = @message.read_events.find_by(viewer_token_hash: viewer_token_hash)
    return head :not_found unless read_event

    if read_event.update(reaction: params[:reaction])
      render json: { success: true, reaction: read_event.reaction }
    else
      render json: { success: false, errors: read_event.errors.full_messages }, status: :unprocessable_entity
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
