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
    assert_select "h1", "읽었어?"
    assert_select ".tagline"
    assert_select ".description"
  end

  test "home page contains CTA button" do
    get root_url
    assert_select "a.btn-primary", "메시지 만들어보기"
    assert_select "a[href=?]", new_message_path
  end

  test "home page shows login prompt when not logged in" do
    get root_url
    assert_select ".login-prompt"
    assert_select ".login-prompt a[href=?]", login_path
  end

  test "home page shows sent messages section when logged in" do
    login_as(@user)
    get root_url
    assert_select ".sent-messages"
    assert_select ".sent-messages h2", "보낸 메시지"
  end

  test "home page shows empty state when logged in with no messages" do
    login_as(@user)
    get root_url
    assert_select ".empty-state"
    assert_select ".empty-state", /아직 보낸 메시지가 없습니다/
  end

  test "home page shows message list when logged in with messages" do
    login_as(@user)
    @user.messages.create!(content: "Test message 1")
    @user.messages.create!(content: "Test message 2")

    get root_url
    assert_select ".message-list"
    assert_select ".message-item", 2
  end

  test "home page shows new message button when logged in" do
    login_as(@user)
    get root_url
    assert_select ".cta a[href=?]", new_message_path
  end

  test "home page shows global header with notifications link when logged in" do
    login_as(@user)
    get root_url
    assert_select ".global-header"
    assert_select ".header-nav a[href=?]", notifications_path
  end

  test "home page shows logout button in global header when logged in" do
    login_as(@user)
    get root_url
    assert_select ".global-header .btn-logout"
  end

  test "home page shows message read count" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    message.read_events.create!(viewer_token_hash: "abc123", read_at: Time.current)
    message.read_events.create!(viewer_token_hash: "abc123", read_at: Time.current)
    message.read_events.create!(viewer_token_hash: "def456", read_at: Time.current)
    message.update!(read_count: 3)

    get root_url
    assert_select ".read-count", /2명 \/ 3회/
  end

  test "home page shows password badge for password-protected message" do
    login_as(@user)
    @user.messages.create!(content: "Secret message", password: "secret123")

    get root_url
    assert_select ".password-badge", "비밀번호"
  end

  test "home page shows limit badge for read-limited message" do
    login_as(@user)
    @user.messages.create!(content: "One-time message", max_read_count: 1)

    get root_url
    assert_select ".limit-badge", /제한: 1회/
  end

  test "home page does not show description when logged in" do
    login_as(@user)
    get root_url
    assert_select ".description", false
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
