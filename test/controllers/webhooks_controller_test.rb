# frozen_string_literal: true

require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    @webhook_secret = "test_webhook_secret"
    ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"] = @webhook_secret
  end

  teardown do
    ENV.delete("LEMON_SQUEEZY_WEBHOOK_SECRET")
  end

  test "rejects webhook without signature" do
    post webhooks_lemon_squeezy_path, params: {}, as: :json
    assert_response :unauthorized
  end

  test "rejects webhook with invalid signature" do
    payload = { meta: { event_name: "subscription_created" }, data: {} }.to_json

    post webhooks_lemon_squeezy_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Signature" => "invalid_signature"
      }

    assert_response :unauthorized
  end

  test "accepts webhook with valid signature and creates subscription" do
    variant_id = "1280844"
    payload = {
      meta: { event_name: "subscription_created" },
      data: {
        id: "12345",
        attributes: {
          user_email: @user.email,
          customer_id: 67890,
          variant_id: variant_id,
          renews_at: 1.month.from_now.iso8601
        }
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    post webhooks_lemon_squeezy_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Signature" => signature
      }

    assert_response :ok

    @user.reload
    assert_equal "pro", @user.plan
    assert_equal "active", @user.subscription_status
    assert_equal "12345", @user.lemon_squeezy_subscription_id
    assert_equal "67890", @user.lemon_squeezy_customer_id
    assert_equal variant_id, @user.variant_id
  end

  test "handles subscription_cancelled event" do
    @user.update!(
      plan: "pro",
      subscription_status: "active",
      lemon_squeezy_subscription_id: "12345"
    )

    payload = {
      meta: { event_name: "subscription_cancelled" },
      data: {
        id: "12345",
        attributes: {}
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    post webhooks_lemon_squeezy_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Signature" => signature
      }

    assert_response :ok

    @user.reload
    assert_equal "cancelled", @user.subscription_status
    assert_not_nil @user.cancelled_at
  end

  test "handles subscription_expired event" do
    @user.update!(
      plan: "pro",
      subscription_status: "cancelled",
      lemon_squeezy_subscription_id: "12345"
    )

    payload = {
      meta: { event_name: "subscription_expired" },
      data: {
        id: "12345",
        attributes: {}
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    post webhooks_lemon_squeezy_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Signature" => signature
      }

    assert_response :ok

    @user.reload
    assert_equal "expired", @user.subscription_status
    assert_equal "free", @user.plan
  end

  test "handles subscription_payment_failed event" do
    @user.update!(
      plan: "pro",
      subscription_status: "active",
      lemon_squeezy_subscription_id: "12345"
    )

    payload = {
      meta: { event_name: "subscription_payment_failed" },
      data: {
        id: "99999",
        attributes: {
          subscription_id: 12345
        }
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    post webhooks_lemon_squeezy_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Signature" => signature
      }

    assert_response :ok

    @user.reload
    assert_equal "past_due", @user.subscription_status
  end
end
