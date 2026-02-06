# frozen_string_literal: true

require "test_helper"

class SendWebhookJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
    @message = @user.messages.create!(title: "Test Message", content: "Hello")
    @viewer_token_hash = "abc123"

    # Make user Pro with webhook URL
    @user.update!(
      plan: "pro",
      subscription_status: "active",
      current_period_end: 1.month.from_now,
      webhook_url: "https://example.com/webhook"
    )
  end

  test "does not send webhook for free users" do
    @user.update!(plan: "free", subscription_status: nil)

    assert_no_difference "Notification.count" do
      SendWebhookJob.perform_now(@message.id, @viewer_token_hash)
    end
  end

  test "does not send webhook if user has no webhook URL" do
    @user.update!(webhook_url: nil)

    assert_no_difference "Notification.count" do
      SendWebhookJob.perform_now(@message.id, @viewer_token_hash)
    end
  end

  test "creates webhook notification for pro user with webhook URL" do
    # Stub the HTTP request
    stub_request(:post, "https://example.com/webhook")
      .to_return(status: 200, body: "", headers: {})

    assert_difference "Notification.count", 1 do
      SendWebhookJob.perform_now(@message.id, @viewer_token_hash)
    end

    notification = Notification.last
    assert_equal "webhook", notification.notification_type
    assert_equal "https://example.com/webhook", notification.recipient
    assert_equal "sent", notification.status
  end

  test "marks notification as failed if webhook returns error" do
    stub_request(:post, "https://example.com/webhook")
      .to_return(status: 500, body: "Internal Server Error", headers: {})

    assert_difference "Notification.count", 1 do
      SendWebhookJob.perform_now(@message.id, @viewer_token_hash)
    end

    notification = Notification.last
    assert_equal "failed", notification.status
  end

  test "does not create duplicate notifications for same viewer" do
    stub_request(:post, "https://example.com/webhook")
      .to_return(status: 200, body: "", headers: {})

    # First call
    SendWebhookJob.perform_now(@message.id, @viewer_token_hash)

    # Second call should not create duplicate
    assert_no_difference "Notification.count" do
      SendWebhookJob.perform_now(@message.id, @viewer_token_hash)
    end
  end

  test "sends correct payload structure" do
    stub = stub_request(:post, "https://example.com/webhook")
      .with { |request|
        body = JSON.parse(request.body)
        body["event"] == "message.read" &&
          body["data"]["message_id"] == @message.token &&
          body["data"]["title"] == "Test Message"
      }
      .to_return(status: 200, body: "", headers: {})

    SendWebhookJob.perform_now(@message.id, @viewer_token_hash)

    assert_requested stub
  end

  test "sends Discord-formatted payload for Discord webhooks" do
    @user.update!(webhook_url: "https://discord.com/api/webhooks/123/abc")

    stub = stub_request(:post, "https://discord.com/api/webhooks/123/abc")
      .with { |request|
        body = JSON.parse(request.body)
        body["embeds"].present? &&
          body["embeds"][0]["title"] == "Message Opened" &&
          body["embeds"][0]["description"].include?("Test Message")
      }
      .to_return(status: 200, body: "", headers: {})

    SendWebhookJob.perform_now(@message.id, @viewer_token_hash)

    assert_requested stub
  end

  test "sends Slack-formatted payload for Slack webhooks" do
    @user.update!(webhook_url: "https://hooks.slack.com/services/T123/B456/xyz")

    stub = stub_request(:post, "https://hooks.slack.com/services/T123/B456/xyz")
      .with { |request|
        body = JSON.parse(request.body)
        body["blocks"].present? &&
          body["blocks"][0]["type"] == "header" &&
          body["blocks"][1]["text"]["text"].include?("Test Message")
      }
      .to_return(status: 200, body: "", headers: {})

    SendWebhookJob.perform_now(@message.id, @viewer_token_hash)

    assert_requested stub
  end
end
