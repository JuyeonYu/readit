require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_url
    assert_response :success
    assert_select "input[name='email']"
  end

  test "should create user and login token on login" do
    assert_difference ["User.count", "LoginToken.count"], 1 do
      post login_url, params: { email: "new@example.com" }
    end
    assert_redirected_to login_sent_path
  end

  test "should reuse existing user on login" do
    user = User.create!(email: "existing@example.com")

    assert_no_difference "User.count" do
      assert_difference "LoginToken.count", 1 do
        post login_url, params: { email: "existing@example.com" }
      end
    end
    assert_redirected_to login_sent_path
  end

  test "should show error with blank email" do
    post login_url, params: { email: "" }
    assert_response :unprocessable_entity
  end

  test "should verify valid token and log in" do
    user = User.create!(email: "test@example.com")
    token = user.login_tokens.create!

    get verify_login_url(token: token.token)
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "should reject invalid token" do
    get verify_login_url(token: "invalid")
    assert_redirected_to login_path
  end

  test "should reject used token" do
    user = User.create!(email: "test@example.com")
    token = user.login_tokens.create!
    token.use!

    get verify_login_url(token: token.token)
    assert_redirected_to login_path
  end

  test "should reject expired token" do
    user = User.create!(email: "test@example.com")
    token = user.login_tokens.create!(expires_at: 1.hour.ago)

    get verify_login_url(token: token.token)
    assert_redirected_to login_path
  end

  test "should logout" do
    user = User.create!(email: "test@example.com")
    token = user.login_tokens.create!
    get verify_login_url(token: token.token)

    delete logout_url
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end
end
