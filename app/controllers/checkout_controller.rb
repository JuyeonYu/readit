# frozen_string_literal: true

class CheckoutController < ApplicationController
  before_action :require_login

  def create
    variant_id = params[:variant_id]

    unless variant_id.present?
      redirect_to pricing_path, alert: "Please select a plan"
      return
    end

    checkout_url = LemonSqueezyService.create_checkout(
      variant_id: variant_id,
      user: current_user,
      success_url: checkout_success_url,
      cancel_url: checkout_cancel_url
    )

    if checkout_url
      redirect_to checkout_url, allow_other_host: true
    else
      redirect_to pricing_path, alert: "Unable to create checkout. Please try again."
    end
  end

  def success
    # User will be redirected here after successful payment
    # Actual subscription activation happens via webhook
    flash[:notice] = "Payment successful! Your Pro subscription is now active."
    redirect_to dashboard_path
  end

  def cancel
    redirect_to pricing_path, notice: "Checkout cancelled. Feel free to try again when you're ready."
  end
end
