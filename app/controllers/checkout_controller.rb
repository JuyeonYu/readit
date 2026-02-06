# frozen_string_literal: true

class CheckoutController < ApplicationController
  before_action :require_login

  # GET /upgrade/monthly - Direct link to monthly checkout
  def monthly
    variant_id = Rails.application.config.lemon_squeezy[:pro_monthly_variant_id]
    redirect_to_checkout(variant_id)
  end

  # GET /upgrade/yearly - Direct link to yearly checkout
  def yearly
    variant_id = Rails.application.config.lemon_squeezy[:pro_yearly_variant_id]
    redirect_to_checkout(variant_id)
  end

  def create
    variant_id = params[:variant_id]

    unless variant_id.present?
      redirect_to pricing_path, alert: t('flash.checkout.select_plan')
      return
    end

    redirect_to_checkout(variant_id)
  end

  def success
    # User will be redirected here after successful payment
    # Actual subscription activation happens via webhook
    flash[:notice] = t('flash.checkout.success')
    redirect_to dashboard_path
  end

  def cancel
    redirect_to pricing_path, notice: t('flash.checkout.cancelled')
  end

  private

  def redirect_to_checkout(variant_id)
    unless variant_id.present?
      redirect_to pricing_path, alert: t('flash.checkout.plan_unavailable')
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
      redirect_to pricing_path, alert: t('flash.checkout.checkout_error')
    end
  end
end
