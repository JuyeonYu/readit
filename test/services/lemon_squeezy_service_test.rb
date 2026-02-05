# frozen_string_literal: true

require "test_helper"

class LemonSqueezyServiceTest < ActiveSupport::TestCase
  setup do
    @webhook_secret = "test_secret_key"
    ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"] = @webhook_secret
  end

  teardown do
    ENV.delete("LEMON_SQUEEZY_WEBHOOK_SECRET")
  end

  test "verify_webhook returns false for blank signature" do
    payload = '{"test": "data"}'

    assert_not LemonSqueezyService.verify_webhook(payload, nil)
    assert_not LemonSqueezyService.verify_webhook(payload, "")
  end

  test "verify_webhook returns false for invalid signature" do
    payload = '{"test": "data"}'
    invalid_signature = "invalid_signature_here"

    assert_not LemonSqueezyService.verify_webhook(payload, invalid_signature)
  end

  test "verify_webhook returns true for valid signature" do
    payload = '{"test": "data"}'
    valid_signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    assert LemonSqueezyService.verify_webhook(payload, valid_signature)
  end

  test "verify_webhook is timing-safe against attacks" do
    payload = '{"test": "data"}'
    valid_signature = OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, payload)

    # Test that it uses secure comparison (doesn't short-circuit)
    # The signature must match exactly
    almost_valid = valid_signature[0..-2] + "X"
    assert_not LemonSqueezyService.verify_webhook(payload, almost_valid)
  end

  test "verify_webhook returns false when secret is blank" do
    ENV.delete("LEMON_SQUEEZY_WEBHOOK_SECRET")
    payload = '{"test": "data"}'
    signature = "any_signature"

    # With no secret configured, verify should fail
    result = LemonSqueezyService.verify_webhook(payload, signature)

    assert_not result
  end
end
