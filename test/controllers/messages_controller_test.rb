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

  test "create with valid content saves message and redirects to share" do
    login_as(@user)

    assert_difference "Message.count", 1 do
      post messages_url, params: { message: { content: "Test message" } }
    end

    message = Message.last
    assert_redirected_to share_message_path(message.token)
    assert message.token.present?
    assert_equal @user, message.user
  end

  test "share page shows link" do
    login_as(@user)
    message = @user.messages.create!(content: "Test")

    get share_message_path(message.token)
    assert_response :success
    assert_match message.token, response.body
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
