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

  test "new page contains message form with title and content fields" do
    login_as(@user)
    get new_message_url
    assert_select "form"
    assert_select "input[name='message[title]']"
    assert_select "button[type='submit']"
  end

  test "new page shows user email for notifications" do
    login_as(@user)
    get new_message_url
    assert_match @user.email, response.body
  end

  test "new page contains message settings" do
    login_as(@user)
    get new_message_url
    assert_match "Message Settings", response.body
    assert_select "select[name='message[expires_in]']"
    assert_select "input[name='message[max_read_count]']"
    assert_select "input[name='message[password]']"
  end

  test "create with empty title and content shows error" do
    login_as(@user)
    post messages_url, params: { message: { title: "", content: "" } }
    assert_response :unprocessable_entity
    assert_select "div.bg-red-50"  # Error container
  end

  test "create with valid title and content saves message and redirects to share" do
    login_as(@user)

    assert_difference "Message.count", 1 do
      post messages_url, params: { message: { title: "Test Title", content: "Test message" } }
    end

    message = Message.last
    assert_redirected_to share_message_path(message.token)
    assert message.token.present?
    assert_equal @user, message.user
  end

  test "share page shows link" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test")

    get share_message_path(message.token)
    assert_response :success
    assert_match message.token, response.body
  end

  test "share page shows read analytics section" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test")

    get share_message_path(message.token)
    assert_match "Read Analytics", response.body
  end

  test "share page shows empty state when no read events" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test")

    get share_message_path(message.token)
    assert_match "No one has read this message yet", response.body
  end

  test "share page shows read events grouped by viewer" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.read_events.create!(read_at: 1.hour.ago, viewer_token_hash: "abc123")
    message.read_events.create!(read_at: 30.minutes.ago, viewer_token_hash: "abc123")
    message.read_events.create!(read_at: 20.minutes.ago, viewer_token_hash: "def456")
    message.update!(read_count: 3)

    get share_message_path(message.token)
    assert_match "3", response.body  # Total views count
    assert_match "2", response.body  # Unique readers count
  end

  test "share page shows reader activity" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.read_events.create!(read_at: 2.hours.ago, viewer_token_hash: "abc123")
    message.read_events.create!(read_at: 1.hour.ago, viewer_token_hash: "def456")

    get share_message_path(message.token)
    assert_match "Recent activity", response.body
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
