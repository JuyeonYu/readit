# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :lemon_squeezy ]

  def lemon_squeezy
    payload = request.body.read
    signature = request.headers["X-Signature"]

    unless LemonSqueezyService.verify_webhook(payload, signature)
      head :unauthorized
      return
    end

    event = JSON.parse(payload)
    event_name = event.dig("meta", "event_name")

    case event_name
    when "subscription_created"
      handle_subscription_created(event)
    when "subscription_updated"
      handle_subscription_updated(event)
    when "subscription_cancelled"
      handle_subscription_cancelled(event)
    when "subscription_resumed"
      handle_subscription_resumed(event)
    when "subscription_expired"
      handle_subscription_expired(event)
    when "subscription_payment_success"
      handle_payment_success(event)
    when "subscription_payment_failed"
      handle_payment_failed(event)
    else
      Rails.logger.info "Unhandled Lemon Squeezy event: #{event_name}"
    end

    head :ok
  end

  private

  def handle_subscription_created(event)
    data = event["data"]
    attributes = data["attributes"]
    custom_data = event.dig("meta", "custom_data") || {}
    user_id = custom_data["user_id"]
    user_email = attributes.dig("user_email")
    customer_id = attributes["customer_id"].to_s
    subscription_id = data["id"].to_s
    variant_id = attributes["variant_id"].to_s
    current_period_end = Time.parse(attributes["renews_at"]) if attributes["renews_at"]

    # Try to find user by ID first (from custom data), then by email
    user = User.find_by(id: user_id) if user_id.present?
    user ||= User.find_by(email: user_email)
    return unless user

    user.activate_subscription!(
      customer_id: customer_id,
      subscription_id: subscription_id,
      variant_id: variant_id,
      current_period_end: current_period_end
    )

    Rails.logger.info "Subscription created for user #{user.email} with variant #{variant_id}"
  end

  def handle_subscription_updated(event)
    data = event["data"]
    attributes = data["attributes"]
    subscription_id = data["id"].to_s
    current_period_end = Time.parse(attributes["renews_at"]) if attributes["renews_at"]
    status = attributes["status"]

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    case status
    when "active"
      user.update_subscription_period!(current_period_end: current_period_end)
    when "past_due"
      user.update!(subscription_status: "past_due")
    when "paused"
      user.update!(subscription_status: "paused")
    end

    Rails.logger.info "Subscription updated for user #{user.email}: #{status}"
  end

  def handle_subscription_cancelled(event)
    data = event["data"]
    subscription_id = data["id"].to_s

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    user.cancel_subscription!
    Rails.logger.info "Subscription cancelled for user #{user.email}"
  end

  def handle_subscription_resumed(event)
    data = event["data"]
    attributes = data["attributes"]
    subscription_id = data["id"].to_s
    current_period_end = Time.parse(attributes["renews_at"]) if attributes["renews_at"]

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    user.update!(
      subscription_status: "active",
      cancelled_at: nil,
      current_period_end: current_period_end
    )

    Rails.logger.info "Subscription resumed for user #{user.email}"
  end

  def handle_subscription_expired(event)
    data = event["data"]
    subscription_id = data["id"].to_s

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    user.expire_subscription!
    Rails.logger.info "Subscription expired for user #{user.email}"
  end

  def handle_payment_success(event)
    data = event["data"]
    attributes = data["attributes"]
    subscription_id = attributes["subscription_id"].to_s

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    # Payment succeeded, ensure subscription is active
    if user.subscription_past_due?
      user.update!(subscription_status: "active")
    end

    Rails.logger.info "Payment success for user #{user.email}"
  end

  def handle_payment_failed(event)
    data = event["data"]
    attributes = data["attributes"]
    subscription_id = attributes["subscription_id"].to_s

    user = User.find_by(lemon_squeezy_subscription_id: subscription_id)
    return unless user

    user.update!(subscription_status: "past_due")

    Rails.logger.info "Payment failed for user #{user.email}"
  end
end
