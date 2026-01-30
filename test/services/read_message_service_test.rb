require "test_helper"

class ReadMessageServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
    @message = @user.messages.create!(content: "Test message")
    @viewer_token_hash = Digest::SHA256.hexdigest(SecureRandom.hex(32))
  end

  test "successfully reads message" do
    result = ReadMessageService.call(@message, viewer_token_hash: @viewer_token_hash)

    assert result.success?
    assert result.read_event.present?
    assert_equal 1, @message.reload.read_count
  end

  test "creates read event with correct attributes" do
    user_agent = "Mozilla/5.0"

    result = ReadMessageService.call(
      @message,
      viewer_token_hash: @viewer_token_hash,
      user_agent: user_agent
    )

    assert result.success?
    assert_equal @viewer_token_hash, result.read_event.viewer_token_hash
    assert_equal user_agent, result.read_event.user_agent
    assert result.read_event.read_at.present?
  end

  test "fails when message is not readable" do
    @message.update!(is_active: false)

    result = ReadMessageService.call(@message, viewer_token_hash: @viewer_token_hash)

    assert_not result.success?
    assert_equal "더 이상 읽을 수 없습니다", result.error
    assert_equal 0, @message.reload.read_count
  end

  test "fails when max_read_count reached" do
    @message.update!(max_read_count: 1, read_count: 1)

    result = ReadMessageService.call(@message, viewer_token_hash: @viewer_token_hash)

    assert_not result.success?
    assert_equal 1, @message.reload.read_count
  end

  test "prevents concurrent reads beyond max_read_count" do
    @message.update!(max_read_count: 1)

    results = 3.times.map do
      Thread.new do
        token = Digest::SHA256.hexdigest(SecureRandom.hex(32))
        ReadMessageService.call(@message, viewer_token_hash: token)
      end
    end.map(&:value)

    success_count = results.count(&:success?)

    assert_equal 1, success_count
    assert_equal 1, @message.reload.read_count
  end
end
