class SessionsController < ApplicationController
  def new
  end

  def create
    email = params[:email]&.strip&.downcase

    if email.blank?
      flash.now[:alert] = "이메일을 입력해주세요"
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_create_by!(email: email)
    login_token = user.login_tokens.create!

    AuthMailer.magic_link(user, login_token).deliver_later

    redirect_to login_sent_path, notice: "로그인 링크를 이메일로 보냈습니다"
  end

  def verify
    login_token = LoginToken.valid.find_by(token: params[:token])

    if login_token
      login_token.use!
      session[:user_id] = login_token.user_id
      redirect_path = session.delete(:return_to) || new_message_path
      redirect_to redirect_path, notice: "로그인 되었습니다"
    else
      redirect_to login_path, alert: "유효하지 않거나 만료된 링크입니다"
    end
  end

  def sent
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "로그아웃 되었습니다"
  end
end
