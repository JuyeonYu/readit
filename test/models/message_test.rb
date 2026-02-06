require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should not save message without content" do
    message = @user.messages.build
    assert_not message.save
    assert message.errors[:content].any?
  end

  test "should not save message without user" do
    message = Message.new(title: "Test Title", content: "Test")
    assert_not message.save
    assert message.errors[:user].any?
  end

  test "should save message with title, content and user" do
    message = @user.messages.build(title: "Test Title", content: "Hello, this is a test message")
    assert message.save
  end

  test "should not save message without title" do
    message = @user.messages.build(content: "Test")
    assert_not message.save
    assert message.errors[:title].any?
  end

  test "sender_email returns user email" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    assert_equal @user.email, message.sender_email
  end

  test "should not save message with past expires_at" do
    message = @user.messages.build(title: "Test Title", content: "Test", expires_at: 1.hour.ago)
    assert_not message.save
  end

  test "should save message with future expires_at" do
    message = @user.messages.build(title: "Test Title", content: "Test", expires_at: 1.hour.from_now)
    assert message.save
  end

  test "should not save message with short password" do
    message = @user.messages.build(title: "Test Title", content: "Test", password: "12345")
    assert_not message.save
    assert message.errors[:password].any?
  end

  test "should save message with valid password" do
    message = @user.messages.build(title: "Test Title", content: "Test", password: "123456")
    assert message.save
  end

  test "should save message with max_read_count" do
    message = @user.messages.build(title: "Test Title", content: "Test", max_read_count: 1)
    assert message.save
    assert_equal 1, message.max_read_count
  end

  test "password is encrypted with has_secure_password" do
    message = @user.messages.create!(title: "Test Title", content: "Test", password: "secret123")
    assert message.password_digest.present?
    assert message.authenticate("secret123")
    assert_not message.authenticate("wrongpassword")
  end

  test "generates unique token on create" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    assert message.token.present?
    assert_equal 32, message.token.length
  end

  test "token is unique" do
    message1 = @user.messages.create!(title: "Title 1", content: "Test 1")
    message2 = @user.messages.create!(title: "Title 2", content: "Test 2")
    assert_not_equal message1.token, message2.token
  end

  test "readable? returns true for active message" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    assert message.readable?
  end

  test "readable? returns false when expired" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.update_column(:expires_at, 1.hour.ago)
    assert_not message.readable?
  end

  test "readable? returns false when max_read_count reached" do
    message = @user.messages.create!(title: "Test Title", content: "Test", max_read_count: 1)
    message.update!(read_count: 1)
    assert_not message.readable?
  end

  test "readable? returns false when inactive" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.update!(is_active: false)
    assert_not message.readable?
  end

  test "should not save message with content exceeding max length" do
    long_content = "a" * (Message::CONTENT_MAX_LENGTH + 1)
    message = @user.messages.build(title: "Test Title", content: long_content)
    assert_not message.save
    assert message.errors[:content].any?
  end

  test "should save message with content at max length" do
    max_content = "a" * Message::CONTENT_MAX_LENGTH
    message = @user.messages.build(title: "Test Title", content: max_content)
    assert message.save
  end

  test "content_length returns plain text length" do
    message = @user.messages.create!(title: "Test Title", content: "Hello world")
    assert_equal 11, message.content_length
  end

  # Attachment limit constants tests
  test "attachment max size constant is 5MB" do
    assert_equal 5.megabytes, Message::ATTACHMENT_MAX_SIZE
  end

  test "attachment total max size constant is 20MB" do
    assert_equal 20.megabytes, Message::ATTACHMENT_TOTAL_MAX_SIZE
  end

  test "attachment allowed types includes common image formats" do
    assert_includes Message::ATTACHMENT_ALLOWED_TYPES, "image/jpeg"
    assert_includes Message::ATTACHMENT_ALLOWED_TYPES, "image/png"
    assert_includes Message::ATTACHMENT_ALLOWED_TYPES, "image/gif"
    assert_includes Message::ATTACHMENT_ALLOWED_TYPES, "image/webp"
  end

  test "attachment allowed types does not include non-image formats" do
    assert_not_includes Message::ATTACHMENT_ALLOWED_TYPES, "application/pdf"
    assert_not_includes Message::ATTACHMENT_ALLOWED_TYPES, "text/plain"
    assert_not_includes Message::ATTACHMENT_ALLOWED_TYPES, "application/javascript"
  end

  test "message without attachments passes attachment validation" do
    message = @user.messages.build(title: "Test Title", content: "No attachments here")
    assert message.valid?
  end

  test "message with valid image attachment saves successfully" do
    message = @user.messages.build(title: "Test Title", content: "Test with image")

    # Create a small valid image blob
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    # Attach to content using Action Text
    message.content = ActionText::Content.new("<action-text-attachment sgid=\"#{blob.attachable_sgid}\"></action-text-attachment>")

    assert message.save
  end

  test "message with oversized attachment fails validation" do
    message = @user.messages.build(title: "Test Title", content: "Test")

    # Create an oversized blob (simulate by setting byte_size directly)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * 100),
      filename: "large.jpg",
      content_type: "image/jpeg"
    )
    # Manually update byte_size to exceed limit for testing
    blob.update_column(:byte_size, Message::ATTACHMENT_MAX_SIZE + 1)

    message.content = ActionText::Content.new("<action-text-attachment sgid=\"#{blob.attachable_sgid}\"></action-text-attachment>")

    assert_not message.valid?
    assert message.errors[:content].any?
  end

  test "message with invalid file type fails validation" do
    message = @user.messages.build(title: "Test Title", content: "Test")

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake pdf data"),
      filename: "document.pdf",
      content_type: "application/pdf"
    )

    message.content = ActionText::Content.new("<action-text-attachment sgid=\"#{blob.attachable_sgid}\"></action-text-attachment>")

    assert_not message.valid?
    assert message.errors[:content].any?
  end

  # Reaction tests
  test "reactions_summary returns empty hash when no reactions" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    assert_equal({}, message.reactions_summary)
  end

  test "reactions_summary returns counts grouped by reaction" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.read_events.create!(viewer_token_hash: "abc1", read_at: Time.current, reaction: "👍")
    message.read_events.create!(viewer_token_hash: "abc2", read_at: Time.current, reaction: "👍")
    message.read_events.create!(viewer_token_hash: "abc3", read_at: Time.current, reaction: "❤️")

    summary = message.reactions_summary
    assert_equal 2, summary["👍"]
    assert_equal 1, summary["❤️"]
  end

  test "reactions_summary excludes nil reactions" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    message.read_events.create!(viewer_token_hash: "abc1", read_at: Time.current, reaction: "👍")
    message.read_events.create!(viewer_token_hash: "abc2", read_at: Time.current, reaction: nil)

    summary = message.reactions_summary
    assert_equal({ "👍" => 1 }, summary)
  end

  test "total_reactions_count returns count of reactions" do
    message = @user.messages.create!(title: "Test Title", content: "Test")
    assert_equal 0, message.total_reactions_count

    message.read_events.create!(viewer_token_hash: "abc1", read_at: Time.current, reaction: "👍")
    message.read_events.create!(viewer_token_hash: "abc2", read_at: Time.current, reaction: "❤️")
    message.read_events.create!(viewer_token_hash: "abc3", read_at: Time.current, reaction: nil)

    assert_equal 2, message.total_reactions_count
  end
end
