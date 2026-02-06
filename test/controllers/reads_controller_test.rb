require "test_helper"

class ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sender@example.com")
    @message = @user.messages.create!(title: "Test Title", content: "Test message")
  end

  test "show displays preview for valid message" do
    get read_message_path(@message.token)
    assert_response :success
    assert_match "View Message", response.body
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
  end

  test "show displays password field for password-protected message" do
    @message.update!(password: "secret123")

    get read_message_path(@message.token)
    assert_response :success
    assert_select "input[type='password']"
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

  # One-time read integration tests
  test "one-time read: first read succeeds" do
    @message.update!(max_read_count: 1)

    post read_message_path(@message.token)
    assert_response :success
    assert_equal 1, @message.reload.read_count
  end

  test "one-time read: second read fails after first read" do
    @message.update!(max_read_count: 1)

    # First read succeeds
    post read_message_path(@message.token)
    assert_response :success
    assert_equal 1, @message.reload.read_count

    # Second read redirects to expired
    post read_message_path(@message.token)
    assert_redirected_to expired_message_path
    assert_equal 1, @message.reload.read_count  # Count should not increase
  end

  test "one-time read: preview page redirects to expired after message is read" do
    @message.update!(max_read_count: 1)

    # First read the message
    post read_message_path(@message.token)
    assert_response :success

    # Preview page should redirect to expired
    get read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  test "one-time read: different users cannot read after first read" do
    @message.update!(max_read_count: 1)

    # First user reads
    post read_message_path(@message.token)
    assert_response :success

    # Clear cookies to simulate different user
    reset!

    # Different user tries to read - should redirect to expired
    get read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  # Expire after integration tests
  test "expire after: message is readable before expiration" do
    @message.update!(expires_at: 1.hour.from_now)

    get read_message_path(@message.token)
    assert_response :success

    post read_message_path(@message.token)
    assert_response :success
  end

  test "expire after: message is not readable after expiration" do
    @message.update!(expires_at: 1.hour.from_now)

    # Read before expiration - should work
    post read_message_path(@message.token)
    assert_response :success

    # Simulate time passing - message expires
    @message.update_column(:expires_at, 1.hour.ago)

    # Try to view preview - should redirect to expired
    get read_message_path(@message.token)
    assert_redirected_to expired_message_path

    # Try to read - should redirect to expired
    post read_message_path(@message.token)
    assert_redirected_to expired_message_path
  end

  test "expire after: preview page shows expiration" do
    @message.update!(expires_at: 1.day.from_now)

    get read_message_path(@message.token)
    assert_response :success
  end

  test "expire after: different users can read before expiration" do
    @message.update!(expires_at: 1.hour.from_now)

    # First user reads
    post read_message_path(@message.token)
    assert_response :success

    # Clear cookies to simulate different user
    reset!

    # Different user can also read (no max_read_count set)
    get read_message_path(@message.token)
    assert_response :success

    post read_message_path(@message.token)
    assert_response :success
  end

  # Reaction tests
  test "reaction: returns unauthorized without viewer token" do
    patch message_reaction_path(@message.token), params: { reaction: "👍" }, as: :json
    assert_response :unauthorized
  end

  test "reaction: returns not found for non-existent read event" do
    # Read a different message to get a viewer token cookie
    other_message = @user.messages.create!(title: "Other", content: "Other content")
    post read_message_path(other_message.token)

    # Try to react to the original message (no read event for this viewer)
    patch message_reaction_path(@message.token), params: { reaction: "👍" }, as: :json
    assert_response :not_found
  end

  test "reaction: saves valid reaction" do
    # First read the message to create a read event
    post read_message_path(@message.token)
    assert_response :success

    # Now add a reaction
    patch message_reaction_path(@message.token), params: { reaction: "👍" }, as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data["success"]
    assert_equal "👍", response_data["reaction"]

    # Verify the reaction was saved
    read_event = @message.read_events.last
    assert_equal "👍", read_event.reaction
  end

  test "reaction: rejects invalid reaction" do
    # First read the message
    post read_message_path(@message.token)
    assert_response :success

    # Try to add an invalid reaction
    patch message_reaction_path(@message.token), params: { reaction: "👎" }, as: :json
    assert_response :unprocessable_entity

    response_data = JSON.parse(response.body)
    assert_not response_data["success"]
  end

  test "reaction: can change reaction" do
    # First read the message
    post read_message_path(@message.token)
    assert_response :success

    # Add first reaction
    patch message_reaction_path(@message.token), params: { reaction: "👍" }, as: :json
    assert_response :success

    # Change to different reaction
    patch message_reaction_path(@message.token), params: { reaction: "❤️" }, as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_equal "❤️", response_data["reaction"]

    # Verify the reaction was updated
    read_event = @message.read_events.last
    assert_equal "❤️", read_event.reaction
  end

  test "reaction: all allowed reactions work" do
    ReadEvent::ALLOWED_REACTIONS.each do |emoji|
      # Reset for each test
      @message = @user.messages.create!(title: "Test #{emoji}", content: "Test message")

      post read_message_path(@message.token)
      assert_response :success

      patch message_reaction_path(@message.token), params: { reaction: emoji }, as: :json
      assert_response :success, "Expected #{emoji} to be accepted"

      read_event = @message.read_events.last
      assert_equal emoji, read_event.reaction
    end
  end
end
