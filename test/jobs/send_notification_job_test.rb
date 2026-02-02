require "test_helper"

class SendNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.create!(email: "sender@example.com")
    @message = @user.messages.create!(title: "Test Title", content: "Test message")
    @viewer_hash = "abc123"
  end

  test "sends email notification" do
    assert_difference "Notification.count", 1 do
      assert_emails 1 do
        SendNotificationJob.perform_now(@message.id, @viewer_hash)
      end
    end

    notification = Notification.last
    assert_equal @message, notification.message
    assert_equal @user.email, notification.recipient
    assert notification.sent?
    assert notification.sent_at.present?
  end

  test "prevents duplicate notifications for same viewer" do
    assert_difference "Notification.count", 1 do
      assert_emails 1 do
        2.times { SendNotificationJob.perform_now(@message.id, @viewer_hash) }
      end
    end
  end

  test "sends separate notifications for different viewers" do
    assert_difference "Notification.count", 2 do
      assert_emails 2 do
        SendNotificationJob.perform_now(@message.id, "viewer_1")
        SendNotificationJob.perform_now(@message.id, "viewer_2")
      end
    end
  end

  test "same viewer does not get duplicate notification even after time passes" do
    SendNotificationJob.perform_now(@message.id, @viewer_hash)

    travel 1.hour do
      assert_no_difference "Notification.count" do
        assert_emails 0 do
          SendNotificationJob.perform_now(@message.id, @viewer_hash)
        end
      end
    end
  end
end
