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
    assert_select "h1", "알림 목록"
  end

  test "index page shows empty state when no notifications" do
    login_as(@user)
    get notifications_url
    assert_select ".empty-state"
    assert_select ".empty-state", /아직 발송된 알림이 없습니다/
  end

  test "index page shows notifications list" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-1",
      sent_at: Time.current
    )

    get notifications_url
    assert_select ".notifications-list"
    assert_select ".notification-item", 1
  end

  test "index page shows notification status" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-2",
      sent_at: Time.current
    )

    get notifications_url
    assert_select ".notification-status-sent", "발송완료"
  end

  test "index page shows notification type" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-3",
      sent_at: Time.current
    )

    get notifications_url
    assert_select ".notification-type", "이메일"
  end

  test "index page links to message share page" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-4",
      sent_at: Time.current
    )

    get notifications_url
    assert_select ".notification-message a[href=?]", share_message_path(message.token)
  end

  test "notifications are shown in descending order" do
    login_as(@user)
    message = @user.messages.create!(content: "Test message")
    older = message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-older",
      sent_at: 2.hours.ago,
      created_at: 2.hours.ago
    )
    newer = message.notifications.create!(
      notification_type: :email,
      recipient: @user.email,
      status: :sent,
      idempotency_key: "test-key-newer",
      sent_at: 1.hour.ago,
      created_at: 1.hour.ago
    )

    get notifications_url
    assert_select ".notification-item", 2
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
