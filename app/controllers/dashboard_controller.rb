class DashboardController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data

  def index
    @messages = current_user.messages.includes(:read_events)
    if current_user.history_limit_date
      @messages = @messages.where("messages.created_at >= ?", current_user.history_limit_date)
    end
    @messages = @messages.order("messages.created_at DESC")

    # Calculate stats
    @total_messages = @messages.count
    @messages_this_month = current_user.messages_this_month

    # Usage tracking for upgrade prompts
    @message_limit = current_user.message_limit
    @is_free_plan = current_user.free?
    @usage_percentage = @is_free_plan ? [ (@messages_this_month.to_f / @message_limit) * 100, 100 ].min.round : 0
    @days_until_reset = (Time.current.end_of_month.to_date - Time.current.to_date).to_i + 1
    @total_opens = @messages.sum(:read_count)
    @opens_today = current_user.messages.joins(:read_events)
                               .where("read_events.read_at >= ?", Time.current.beginning_of_day)
                               .count

    # Calculate open rate
    opened_messages = @messages.where("read_count > 0").count
    @open_rate = @total_messages > 0 ? ((opened_messages.to_f / @total_messages) * 100).round : 0

    # Calculate average time to first open (in hours)
    messages_with_opens = current_user.messages.joins(:read_events)
                                               .select("messages.*, MIN(read_events.read_at) as first_open_at")
                                               .group("messages.id")
                                               .to_a

    if messages_with_opens.any?
      total_hours = messages_with_opens.sum do |msg|
        ((msg.first_open_at.to_time - msg.created_at) / 1.hour).abs
      end
      @avg_time_to_open = (total_hours / messages_with_opens.length).round(1)
    else
      @avg_time_to_open = 0
    end

    # Opens over time (last 7 days)
    @opens_by_day = current_user.messages.joins(:read_events)
                                .where("read_events.read_at >= ?", 7.days.ago)
                                .group("date(read_events.read_at)")
                                .count

    # Recent messages for table (with pagination if needed)
    @recent_messages = @messages.limit(20)
  end

  def show
    @message = current_user.messages.includes(:read_events).find_by!(token: params[:token])
    @grouped_reads = @message.grouped_reads
  end
end
