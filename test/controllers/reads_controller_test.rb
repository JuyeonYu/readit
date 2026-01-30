require "test_helper"

class ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sender@example.com")
    @message = @user.messages.create!(content: "Test message")
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
end
