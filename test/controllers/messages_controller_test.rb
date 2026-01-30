require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_message_url
    assert_response :success
  end

  test "new page contains message form with content textarea" do
    get new_message_url
    assert_select "form"
    assert_select "textarea[name='message[content]']"
    assert_select "input[type='submit']"
  end

  test "create with empty content shows error" do
    post messages_url, params: { message: { content: "" } }
    assert_response :unprocessable_entity
    assert_select ".error-messages"
  end
end
