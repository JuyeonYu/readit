require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "should not save message without content" do
    message = Message.new
    assert_not message.save
    assert_includes message.errors[:content], "can't be blank"
  end

  test "should save message with content" do
    message = Message.new(content: "Hello, this is a test message")
    assert message.save
  end
end
