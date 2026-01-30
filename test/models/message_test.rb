require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should not save message without content" do
    message = @user.messages.build
    assert_not message.save
    assert_includes message.errors[:content], "can't be blank"
  end

  test "should not save message without user" do
    message = Message.new(content: "Test")
    assert_not message.save
    assert_includes message.errors[:user], "must exist"
  end

  test "should save message with content and user" do
    message = @user.messages.build(content: "Hello, this is a test message")
    assert message.save
  end

  test "sender_email returns user email" do
    message = @user.messages.create!(content: "Test")
    assert_equal @user.email, message.sender_email
  end

  test "should not save message with past expires_at" do
    message = @user.messages.build(content: "Test", expires_at: 1.hour.ago)
    assert_not message.save
  end

  test "should save message with future expires_at" do
    message = @user.messages.build(content: "Test", expires_at: 1.hour.from_now)
    assert message.save
  end

  test "should not save message with short password" do
    message = @user.messages.build(content: "Test", password: "12345")
    assert_not message.save
    assert_includes message.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should save message with valid password" do
    message = @user.messages.build(content: "Test", password: "123456")
    assert message.save
  end

  test "should save message with max_read_count" do
    message = @user.messages.build(content: "Test", max_read_count: 1)
    assert message.save
    assert_equal 1, message.max_read_count
  end

  test "password is encrypted with has_secure_password" do
    message = @user.messages.create!(content: "Test", password: "secret123")
    assert message.password_digest.present?
    assert message.authenticate("secret123")
    assert_not message.authenticate("wrongpassword")
  end

  test "generates unique token on create" do
    message = @user.messages.create!(content: "Test")
    assert message.token.present?
    assert_equal 32, message.token.length
  end

  test "token is unique" do
    message1 = @user.messages.create!(content: "Test 1")
    message2 = @user.messages.create!(content: "Test 2")
    assert_not_equal message1.token, message2.token
  end
end
