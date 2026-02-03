# frozen_string_literal: true

# This job sends the Pro introduction email to users who signed up 3 days ago
# and are still on the free plan.
#
# Schedule this job to run daily, e.g., via cron:
#   0 10 * * * cd /app && bin/rails runner "ProIntroductionJob.perform_now"
#
# Or with Sidekiq/Good Job:
#   ProIntroductionJob.perform_later
#
class ProIntroductionJob < ApplicationJob
  queue_as :default

  def perform
    # Find users who signed up exactly 3 days ago and are still on free plan
    three_days_ago = 3.days.ago.all_day

    User.where(created_at: three_days_ago).find_each do |user|
      next if user.pro?

      OnboardingService.new(user).send_pro_introduction
    end
  end
end
