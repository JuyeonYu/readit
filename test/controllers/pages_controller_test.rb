require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should get home" do
    get root_url
    assert_response :success
  end

  test "home page contains service description when not logged in" do
    get root_url
    assert_match "MessageOpen", response.body
    assert_match "Know When Your", response.body
  end

  test "home page contains CTA button linking to login" do
    get root_url
    assert_match "Get Started", response.body
    assert_select "a[href=?]", login_path
  end

  test "home page shows how it works section when not logged in" do
    get root_url
    assert_match "How MessageOpen Works", response.body
  end

  test "home page shows your messages section when logged in" do
    login_as(@user)
    get root_url
    assert_match "Your Messages", response.body
  end

  test "home page shows empty state when logged in with no messages" do
    login_as(@user)
    get root_url
    assert_match "Create your first message", response.body
  end

  test "home page shows message list when logged in with messages" do
    login_as(@user)
    @user.messages.create!(title: "Title 1", content: "Test message 1")
    @user.messages.create!(title: "Title 2", content: "Test message 2")

    get root_url
    assert_match "Title 1", response.body
    assert_match "Title 2", response.body
  end

  test "home page shows new message button when logged in" do
    login_as(@user)
    get root_url
    assert_select "a[href=?]", new_message_path
  end

  test "home page shows header with notifications link when logged in" do
    login_as(@user)
    get root_url
    assert_select "a[href=?]", notifications_path
  end

  test "home page shows logout button when logged in" do
    login_as(@user)
    get root_url
    assert_select "form[action=?]", logout_path
  end

  test "home page shows message read count" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.read_events.create!(viewer_token_hash: "abc123", read_at: Time.current)
    message.read_events.create!(viewer_token_hash: "abc123", read_at: Time.current)
    message.read_events.create!(viewer_token_hash: "def456", read_at: Time.current)
    message.update!(read_count: 3)

    get root_url
    assert_match "2 readers", response.body
    assert_match "3 views", response.body
  end

  test "home page shows password badge for password-protected message" do
    login_as(@user)
    @user.messages.create!(title: "Secret Title", content: "Secret message", password: "secret123")

    get root_url
    assert_match "Protected", response.body
  end

  test "home page shows limit badge for read-limited message" do
    login_as(@user)
    @user.messages.create!(title: "One-time Title", content: "One-time message", max_read_count: 1)

    get root_url
    assert_match "Limit: 1", response.body
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
