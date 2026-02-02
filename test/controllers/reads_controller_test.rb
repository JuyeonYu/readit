require "test_helper"

class ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sender@example.com")
    @message = @user.messages.create!(title: "Test Title", content: "Test message")
  end

  test "show displays preview for valid message" do
    get read_message_path(@message.token)
    assert_response :success
    assert_match "읽을까요?", response.body
    assert_match @user.email, response.body
  end

  test "show redirects to expired for expired message" do
    @message.update_column(:expires_at, 1.hour.ago)

    get read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  test "show redirects to expired when max_read_count reached" do
    @message.update!(max_read_count: 1, read_count: 1)

    get read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  test "show redirects to expired when message is inactive" do
    @message.update!(is_active: false)

    get read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  test "show returns 404 for invalid token" do
    get read_message_path("invalid-token")
    assert_response :not_found
  end

  test "expired page renders" do
    get expired_message_path
    assert_response :success
    assert_match "메시지를 볼 수 없습니다", response.body
  end

  test "show displays password field for password-protected message" do
    @message.update!(password: "secret123")

    get read_message_path(@message.token)
    assert_response :success
    assert_select "input[type='password'][name='password']"
  end

  test "show does not display password field for message without password" do
    get read_message_path(@message.token)
    assert_response :success
    assert_select "input[type='password']", count: 0
  end

  test "create with wrong password shows error" do
    @message.update!(password: "secret123")

    post read_message_path(@message.token), params: { password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_match "비밀번호가 올바르지 않습니다", response.body
  end

  test "create with correct password succeeds" do
    @message.update!(password: "secret123")

    post read_message_path(@message.token), params: { password: "secret123" }
    assert_response :success
  end

  test "create without password succeeds for unprotected message" do
    post read_message_path(@message.token)
    assert_response :success
  end

  test "create increments read_count" do
    assert_difference -> { @message.reload.read_count }, 1 do
      post read_message_path(@message.token)
    end
  end

  test "create creates ReadEvent" do
    assert_difference "ReadEvent.count", 1 do
      post read_message_path(@message.token)
    end

    read_event = ReadEvent.last
    assert_equal @message, read_event.message
    assert read_event.viewer_token_hash.present?
  end

  test "create displays message content" do
    post read_message_path(@message.token)
    assert_response :success
    assert_match @message.title, response.body
  end

  test "create redirects to expired when message becomes unreadable" do
    @message.update!(max_read_count: 1, read_count: 1)

    post read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end
end
