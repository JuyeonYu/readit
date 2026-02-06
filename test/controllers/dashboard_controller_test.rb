require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "should redirect to login when not logged in" do
    get dashboard_path
    assert_redirected_to login_path
  end

  test "should get index when logged in" do
    login_as(@user)
    get dashboard_path
    assert_response :success
  end

  # History limit tests for free users
  test "free user sees messages from last 7 days" do
    login_as(@user)

    # Create a message within 7 days
    recent_message = @user.messages.create!(title: "Recent", content: "Test")

    get dashboard_path
    assert_response :success
    assert_match "Recent", response.body
  end

  test "free user does not see messages older than 7 days" do
    login_as(@user)

    # Create an old message (8 days ago)
    old_message = @user.messages.create!(title: "Old Message", content: "Test")
    old_message.update_column(:created_at, 8.days.ago)

    # Create a recent message
    recent_message = @user.messages.create!(title: "Recent Message", content: "Test")

    get dashboard_path
    assert_response :success
    assert_match "Recent Message", response.body
    assert_no_match(/Old Message/, response.body)
  end

  test "free user message exactly 7 days old is visible" do
    login_as(@user)

    # Create a message exactly 7 days ago (should be visible)
    message = @user.messages.create!(title: "Edge Case Message", content: "Test")
    message.update_column(:created_at, 7.days.ago + 1.hour)

    get dashboard_path
    assert_response :success
    assert_match "Edge Case Message", response.body
  end

  # History limit tests for pro users (unlimited history)
  test "pro user sees messages from any time period" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: "test",
      current_period_end: 1.month.from_now
    )
    login_as(@user)

    # Create a message 30 days ago
    old_message = @user.messages.create!(title: "Month Old Message", content: "Test")
    old_message.update_column(:created_at, 30.days.ago)

    # Create a recent message
    recent_message = @user.messages.create!(title: "Recent Message", content: "Test")

    get dashboard_path
    assert_response :success
    assert_match "Month Old Message", response.body
    assert_match "Recent Message", response.body
  end

  test "pro user sees very old messages (unlimited history)" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: "test",
      current_period_end: 1.month.from_now
    )
    login_as(@user)

    # Create a very old message (2 years ago)
    very_old_message = @user.messages.create!(title: "Two Year Old Message", content: "Test")
    very_old_message.update_column(:created_at, 2.years.ago)

    # Create a recent message
    recent_message = @user.messages.create!(title: "Recent Message", content: "Test")

    get dashboard_path
    assert_response :success
    assert_match "Two Year Old Message", response.body
    assert_match "Recent Message", response.body
  end

  test "pro user sees messages 8 days old (outside free limit)" do
    @user.activate_subscription!(
      customer_id: "12345",
      subscription_id: "67890",
      variant_id: "test",
      current_period_end: 1.month.from_now
    )
    login_as(@user)

    # Create a message 8 days ago (outside free limit but pro has no limit)
    message = @user.messages.create!(title: "Eight Day Old Message", content: "Test")
    message.update_column(:created_at, 8.days.ago)

    get dashboard_path
    assert_response :success
    assert_match "Eight Day Old Message", response.body
  end

  private

  def login_as(user)
    post login_url, params: { email: user.email }
    token = LoginToken.last
    get verify_login_url(token: token.token)
  end
end
