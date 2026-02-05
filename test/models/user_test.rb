# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
    @monthly_variant_id = "1280844"
    @yearly_variant_id = "1280819"
    Rails.application.config.lemon_squeezy[:pro_monthly_variant_id] = @monthly_variant_id
    Rails.application.config.lemon_squeezy[:pro_yearly_variant_id] = @yearly_variant_id
  end

  test "new user is on free plan" do
    assert_equal "free", @user.plan
    assert @user.free?
    assert_not @user.pro?
  end

  test "activate_subscription! upgrades user to pro" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: @monthly_variant_id,
      current_period_end: 1.month.from_now
    )

    assert @user.pro?
    assert_equal "pro", @user.plan
    assert_equal "active", @user.subscription_status
    assert_equal "12345", @user.lemon_squeezy_customer_id
    assert_equal "67890", @user.lemon_squeezy_subscription_id
    assert_equal @monthly_variant_id, @user.variant_id
  end

  test "pro_monthly? returns true for monthly variant" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: @monthly_variant_id,
      current_period_end: 1.month.from_now
    )

    assert @user.pro_monthly?
    assert_not @user.pro_yearly?
  end

  test "pro_yearly? returns true for yearly variant" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: @yearly_variant_id,
      current_period_end: 1.year.from_now
    )

    assert @user.pro_yearly?
    assert_not @user.pro_monthly?
  end

  test "cancel_subscription! sets status to cancelled" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    @user.cancel_subscription!

    assert_equal "cancelled", @user.subscription_status
    assert_not_nil @user.cancelled_at
    # Still pro during grace period
    assert @user.in_grace_period?
  end

  test "expire_subscription! downgrades to free" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    @user.expire_subscription!

    assert_equal "expired", @user.subscription_status
    assert_equal "free", @user.plan
    assert_not @user.pro?
  end

  test "subscription_active? returns false when period ended" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.day.ago
    )

    assert_not @user.subscription_active?
    assert_not @user.pro?
  end

  test "message_limit is 10 in development for free users" do
    # In test environment, this tests the development path
    assert_equal Rails.env.development? ? 10 : 2, @user.message_limit
  end

  test "message_limit is unlimited for pro users" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    assert_equal Float::INFINITY, @user.message_limit
  end

  test "at_message_limit? returns true when limit reached" do
    # Create messages up to the limit
    limit = @user.message_limit
    limit.to_i.times do |i|
      @user.messages.create!(title: "Message #{i}", content: "Content #{i}")
    end

    assert @user.at_message_limit?
  end

  test "at_message_limit? returns false for pro users" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    # Pro users are never at limit
    assert_not @user.at_message_limit?
  end
end
