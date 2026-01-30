require "test_helper"

class SendNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.create!(email: "sender@example.com")
    @message = @user.messages.create!(content: "Test message")
  end

  test "sends email notification" do
    assert_difference "Notification.count", 1 do
      assert_emails 1 do
        SendNotificationJob.perform_now(@message.id)
      end
    end

    notification = Notification.last
    assert_equal @message, notification.message
    assert_equal @user.email, notification.recipient
    assert notification.sent?
    assert notification.sent_at.present?
  end

  test "prevents duplicate notifications within 5 minutes" do
    assert_difference "Notification.count", 1 do
      assert_emails 1 do
        2.times { SendNotificationJob.perform_now(@message.id) }
      end
    end
  end

  test "creates new notification after 5 minute bucket" do
    # First notification
    SendNotificationJob.perform_now(@message.id)

    # Simulate time passing to next bucket
    travel 6.minutes do
      assert_difference "Notification.count", 1 do
        SendNotificationJob.perform_now(@message.id)
      end
    end
  end
end
