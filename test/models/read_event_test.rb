require "test_helper"

class ReadEventTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
    @message = @user.messages.create!(title: "Test", content: "Content")
  end

  test "allowed reactions constant is defined" do
    assert_equal %w[👍 ❤️ 😊 🎉 🙏], ReadEvent::ALLOWED_REACTIONS
  end

  test "valid read event saves successfully" do
    read_event = @message.read_events.build(
      viewer_token_hash: "abc123",
      read_at: Time.current
    )
    assert read_event.save
  end

  test "read event with valid reaction saves successfully" do
    ReadEvent::ALLOWED_REACTIONS.each do |emoji|
      read_event = @message.read_events.build(
        viewer_token_hash: SecureRandom.hex(16),
        read_at: Time.current,
        reaction: emoji
      )
      assert read_event.save, "Expected #{emoji} to be a valid reaction"
    end
  end

  test "read event with invalid reaction fails validation" do
    read_event = @message.read_events.build(
      viewer_token_hash: "abc123",
      read_at: Time.current,
      reaction: "👎"
    )
    assert_not read_event.save
    assert read_event.errors[:reaction].any?
  end

  test "read event with nil reaction is valid" do
    read_event = @message.read_events.build(
      viewer_token_hash: "abc123",
      read_at: Time.current,
      reaction: nil
    )
    assert read_event.save
  end

  test "reaction can be updated after creation" do
    read_event = @message.read_events.create!(
      viewer_token_hash: "abc123",
      read_at: Time.current
    )

    assert_nil read_event.reaction

    read_event.update!(reaction: "👍")
    assert_equal "👍", read_event.reload.reaction
  end

  test "reaction can be changed to different valid reaction" do
    read_event = @message.read_events.create!(
      viewer_token_hash: "abc123",
      read_at: Time.current,
      reaction: "👍"
    )

    read_event.update!(reaction: "❤️")
    assert_equal "❤️", read_event.reload.reaction
  end
end
