class DashboardController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data

  def index
    # Don't use includes(:read_events) - it loads ALL read_events into memory
    # Stats are calculated via separate efficient queries
    @messages = current_user.messages
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

    # Calculate average time to first open (in hours) - computed in database for efficiency
    @avg_time_to_open = calculate_avg_time_to_open || 0

    # Opens over time (last 7 days)
    @opens_by_day = current_user.messages.joins(:read_events)
                                .where("read_events.read_at >= ?", 7.days.ago)
                                .group("date(read_events.read_at)")
                                .count

    # Recent messages for table with pagination
    # Use with_rich_text_content_and_embeds to eager load Action Text content and attachments
    @pagy, @recent_messages = pagy(
      @messages.with_rich_text_content_and_embeds
    )
  end

  def show
    # Don't use includes(:read_events) - grouped_reads has its own optimized query
    @message = current_user.messages.find_by!(token: params[:token])
    result = @message.grouped_reads(limit: 20)
    @grouped_reads = result[:viewers]
    @total_viewers = result[:total_viewers]
    @has_more_viewers = result[:has_more]
  end

  private

  def calculate_avg_time_to_open
    # Use database-level calculation to avoid loading all records into memory
    # Compatible with both SQLite and PostgreSQL
    time_diff_expr = if ActiveRecord::Base.connection.adapter_name.downcase.include?("sqlite")
      "(julianday(MIN(read_events.read_at)) - julianday(messages.created_at)) * 24"
    else
      "EXTRACT(EPOCH FROM (MIN(read_events.read_at) - messages.created_at)) / 3600"
    end

    subquery = current_user.messages
      .joins(:read_events)
      .where("messages.created_at >= ?", 30.days.ago)
      .group("messages.id")
      .select("#{time_diff_expr} as hours_to_open")

    result = Message.from(subquery, :subquery).average(:hours_to_open)
    result&.abs&.round(1)
  end
end
