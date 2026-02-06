# frozen_string_literal: true

class BillingController < ApplicationController
  before_action :require_login
  before_action :set_navigation_data

  def show
    @subscription_status = current_user.subscription_status
    @plan = current_user.plan
    @current_period_end = current_user.current_period_end
    @cancelled_at = current_user.cancelled_at
    @in_grace_period = current_user.in_grace_period?
  end

  def portal
    unless current_user.lemon_squeezy_customer_id.present?
      redirect_to billing_path, alert: t('flash.billing.no_subscription')
      return
    end

    portal_url = LemonSqueezyService.get_customer_portal_url(current_user.lemon_squeezy_customer_id)

    if portal_url
      redirect_to portal_url, allow_other_host: true
    else
      redirect_to billing_path, alert: t('flash.billing.portal_error')
    end
  end
end
