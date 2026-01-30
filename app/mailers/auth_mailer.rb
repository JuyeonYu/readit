class AuthMailer < ApplicationMailer
  def magic_link(user, login_token)
    @user = user
    @login_url = verify_login_url(token: login_token.token)

    mail(to: user.email, subject: "[읽었어?] 로그인 링크")
  end
end
