# frozen_string_literal: true

# Lemon Squeezy Configuration
#
# Set these environment variables or use Rails credentials:
#
# ENV variables:
#   LEMON_SQUEEZY_API_KEY=your_api_key
#   LEMON_SQUEEZY_STORE_ID=your_store_id
#   LEMON_SQUEEZY_WEBHOOK_SECRET=your_webhook_secret
#   LEMON_SQUEEZY_PRO_MONTHLY_VARIANT_ID=your_variant_id
#   LEMON_SQUEEZY_PRO_YEARLY_VARIANT_ID=your_variant_id
#
# Or Rails credentials (rails credentials:edit):
#   lemon_squeezy:
#     api_key: your_api_key
#     store_id: your_store_id
#     webhook_secret: your_webhook_secret
#     pro_monthly_variant_id: your_variant_id
#     pro_yearly_variant_id: your_variant_id

Rails.application.config.lemon_squeezy = {
  api_key: Rails.application.credentials.dig(:lemon_squeezy, :api_key) || ENV["LEMON_SQUEEZY_API_KEY"],
  store_id: Rails.application.credentials.dig(:lemon_squeezy, :store_id) || ENV["LEMON_SQUEEZY_STORE_ID"],
  webhook_secret: Rails.application.credentials.dig(:lemon_squeezy, :webhook_secret) || ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"],
  pro_monthly_variant_id: Rails.application.credentials.dig(:lemon_squeezy, :pro_monthly_variant_id) || ENV["LEMON_SQUEEZY_PRO_MONTHLY_VARIANT_ID"],
  pro_yearly_variant_id: Rails.application.credentials.dig(:lemon_squeezy, :pro_yearly_variant_id) || ENV["LEMON_SQUEEZY_PRO_YEARLY_VARIANT_ID"]
}
