class SessionsController < ApplicationController
  def new
  end

  def create
    email = params[:email]&.strip&.downcase

    if email.blank?
      flash.now[:alert] = "Please enter your email"
      return render :new, status: :unprocessable_entity
    end

    user = User.find_by(email: email)
    is_new_user = user.nil?

    user ||= User.create!(email: email)
    login_token = user.login_tokens.create!

    # Send welcome email for new users
    if is_new_user
      OnboardingMailer.welcome(user).deliver_later
    end

    AuthMailer.magic_link(user, login_token).deliver_later

    redirect_to login_sent_path, notice: "Check your email for a login link"
  end

  def verify
    login_token = LoginToken.valid.find_by(token: params[:token])

    if login_token
      login_token.use!
      session[:user_id] = login_token.user_id
      redirect_path = session.delete(:return_to) || new_message_path
      redirect_to redirect_path, notice: "You're now logged in"
    else
      redirect_to login_path, alert: "Invalid or expired login link"
    end
  end

  def sent
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been logged out"
  end
end
