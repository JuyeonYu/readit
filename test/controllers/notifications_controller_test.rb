require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should redirect to login when not logged in" do
    get notifications_url
    assert_redirected_to login_path
  end

  test "should get index when logged in" do
    login_as(@user)
    get notifications_url
    assert_response :success
  end

  test "index page shows notifications title" do
    login_as(@user)
    get notifications_url
    assert_match "Notifications", response.body
  end

  test "index page shows empty state when no notifications" do
    login_as(@user)
    get notifications_url
    assert_match "No notifications yet", response.body
  end

  test "index page shows notifications list" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-1",
      sent_at: Time.current
    )

    get notifications_url
    assert_match "Test Title", response.body
  end

  test "index page shows notification status" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-2",
      sent_at: Time.current
    )

    get notifications_url
    assert_match "Sent", response.body
  end

  test "index page shows notification type" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-3",
      sent_at: Time.current
    )

    get notifications_url
    assert_match "Email", response.body
  end

  test "index page links to message share page" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-4",
      sent_at: Time.current
    )

    get notifications_url
    assert_select "a[href=?]", share_message_path(message.token)
  end

  test "notifications are shown" do
    login_as(@user)
    message = @user.messages.create!(title: "Test Title", content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-older",
      sent_at: 2.hours.ago,
      created_at: 2.hours.ago
    )
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-newer",
      sent_at: 1.hour.ago,
      created_at: 1.hour.ago
    )

    get notifications_url
    # Both notifications should be visible
    assert_match @user.email, response.body
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
