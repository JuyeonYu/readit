require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should redirect to login when not logged in" do
    get new_message_url
    assert_redirected_to login_path
  end

  test "should get new when logged in" do
    login_as(@user)
    get new_message_url
    assert_response :success
  end

  test "new page contains message form with content textarea" do
    login_as(@user)
    get new_message_url
    assert_select "form"
    assert_select "textarea[name='message[content]']"
    assert_select "input[type='submit']"
  end

  test "new page shows user email for notifications" do
    login_as(@user)
    get new_message_url
    assert_match @user.email, response.body
  end

  test "new page contains options section" do
    login_as(@user)
    get new_message_url
    assert_select "fieldset.options-section"
    assert_select "input[name='message[expires_at]']"
    assert_select "input[name='message[max_read_count]']"
    assert_select "input[name='message[password]']"
  end

  test "create with empty content shows error" do
    login_as(@user)
    post messages_url, params: { message: { content: "" } }
    assert_response :unprocessable_entity
    assert_select ".error-messages"
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
