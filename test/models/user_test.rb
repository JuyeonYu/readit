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

  # Admin tests
  test "admin? returns true for admin email" do
    ENV["ADMIN_EMAIL"] = "admin@example.com"
    admin_user = User.create!(email: "admin@example.com")
    assert admin_user.admin?
  end

  test "admin? returns false for non-admin email" do
    ENV["ADMIN_EMAIL"] = "admin@example.com"
    assert_not @user.admin?
  end

  test "admin user has pro privileges" do
    ENV["ADMIN_EMAIL"] = "admin@example.com"
    admin_user = User.create!(email: "admin@example.com")
    assert admin_user.pro?
    assert_not admin_user.free?
  end

  test "admin user is pro without subscription" do
    ENV["ADMIN_EMAIL"] = "admin@example.com"
    admin_user = User.create!(email: "admin@example.com")
    assert_equal "free", admin_user.plan
    assert_nil admin_user.subscription_status
    assert admin_user.pro?  # Still pro because admin
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

  test "message_limit is 10 for free users" do
    assert_equal User::FREE_MESSAGE_LIMIT, @user.message_limit
    assert_equal 10, @user.message_limit
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
    # Set monthly count to the limit
    @user.update_columns(
      monthly_message_count: User::FREE_MESSAGE_LIMIT,
      monthly_message_count_reset_at: Time.current
    )

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

  # Monthly message count tests
  test "messages_this_month returns monthly_message_count" do
    @user.update_columns(monthly_message_count: 5, monthly_message_count_reset_at: Time.current)

    assert_equal 5, @user.messages_this_month
  end

  test "increment_monthly_message_count! increases count by 1" do
    @user.update_columns(monthly_message_count: 3, monthly_message_count_reset_at: Time.current)

    @user.increment_monthly_message_count!

    assert_equal 4, @user.monthly_message_count
  end

  test "monthly count resets when new month starts" do
    # Set count to 5 from last month
    @user.update_columns(
      monthly_message_count: 5,
      monthly_message_count_reset_at: 1.month.ago
    )

    # Calling messages_this_month should trigger reset
    count = @user.messages_this_month

    assert_equal 0, count
    assert_equal 0, @user.monthly_message_count
    assert @user.monthly_message_count_reset_at >= Time.current.beginning_of_month
  end

  test "monthly count does not reset within same month" do
    # Set count to 5 from this month
    @user.update_columns(
      monthly_message_count: 5,
      monthly_message_count_reset_at: Time.current.beginning_of_month
    )

    count = @user.messages_this_month

    assert_equal 5, count
    assert_equal 5, @user.monthly_message_count
  end

  test "deleting messages does not decrease monthly count" do
    @user.update_columns(monthly_message_count: 0, monthly_message_count_reset_at: Time.current)

    # Create and increment
    message = @user.messages.create!(title: "Test", content: "Content")
    @user.increment_monthly_message_count!
    assert_equal 1, @user.messages_this_month

    # Delete the message
    message.destroy

    # Count should still be 1
    assert_equal 1, @user.messages_this_month
    assert_equal 0, @user.messages.count
  end

  test "at_message_limit? uses monthly_message_count" do
    @user.update_columns(
      monthly_message_count: User::FREE_MESSAGE_LIMIT,
      monthly_message_count_reset_at: Time.current
    )

    assert @user.at_message_limit?
  end

  test "at_message_limit? resets and returns false at new month" do
    # User was at limit last month
    @user.update_columns(
      monthly_message_count: User::FREE_MESSAGE_LIMIT,
      monthly_message_count_reset_at: 1.month.ago
    )

    # Should reset and not be at limit anymore
    assert_not @user.at_message_limit?
    assert_equal 0, @user.monthly_message_count
  end

  # History limit tests
  test "history limit constant is defined for free users" do
    assert_equal 7, User::FREE_HISTORY_DAYS
  end

  test "history_limit_date returns 7 days ago for free user" do
    freeze_time do
      assert_in_delta 7.days.ago, @user.history_limit_date, 1.second
    end
  end

  test "history_limit_date returns nil for pro user (unlimited)" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    assert_nil @user.history_limit_date
  end

  test "history_limit_date changes when user upgrades to pro" do
    freeze_time do
      # Free user
      free_limit = @user.history_limit_date
      assert_in_delta 7.days.ago, free_limit, 1.second

      # Upgrade to pro
      @user.activate_subscription!(
        customer_id: "12345",
        subscription_id: "67890",
        current_period_end: 1.month.from_now
      )

      # Pro user has unlimited history (nil)
      assert_nil @user.history_limit_date
    end
  end

  test "history_limit_date changes when pro subscription expires" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      current_period_end: 1.month.from_now
    )

    freeze_time do
      # Pro user has unlimited history
      assert_nil @user.history_limit_date

      # Subscription expires
      @user.expire_subscription!

      # Back to free limit
      assert_in_delta 7.days.ago, @user.history_limit_date, 1.second
    end
  end
end
