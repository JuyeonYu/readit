require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_url
    assert_response :success
  end

  test "home page contains service description" do
    get root_url
    assert_select "h1", "읽었어?"
    assert_select ".tagline"
    assert_select ".description"
  end

  test "home page contains CTA button" do
    get root_url
    assert_select "a.btn-primary", "메시지 만들어보기"
    assert_select "a[href=?]", new_message_path
  end
end
