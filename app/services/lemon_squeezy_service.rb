# frozen_string_literal: true

require "net/http"
require "json"

class LemonSqueezyService
  BASE_URL = "https://api.lemonsqueezy.com/v1"

  class << self
    def create_checkout(variant_id:, user:, success_url:, cancel_url:)
      response = post("/checkouts", {
        data: {
          type: "checkouts",
          attributes: {
            checkout_data: {
              email: user.email,
              custom: {
                user_id: user.id.to_s
              }
            },
            product_options: {
              redirect_url: success_url
            },
            checkout_options: {
              button_color: "#4F46E5"
            }
          },
          relationships: {
            store: {
              data: {
                type: "stores",
                id: store_id
              }
            },
            variant: {
              data: {
                type: "variants",
                id: variant_id.to_s
              }
            }
          }
        }
      })

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data.dig("data", "attributes", "url")
    rescue StandardError => e
      Rails.logger.error "Lemon Squeezy checkout error: #{e.message}"
      nil
    end

    def get_customer_portal_url(customer_id)
      response = get("/customers/#{customer_id}")

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data.dig("data", "attributes", "urls", "customer_portal")
    rescue StandardError => e
      Rails.logger.error "Lemon Squeezy portal error: #{e.message}"
      nil
    end

    def cancel_subscription(subscription_id)
      response = delete("/subscriptions/#{subscription_id}")
      response.is_a?(Net::HTTPSuccess)
    rescue StandardError => e
      Rails.logger.error "Lemon Squeezy cancel error: #{e.message}"
      false
    end

    def resume_subscription(subscription_id)
      response = patch("/subscriptions/#{subscription_id}", {
        data: {
          type: "subscriptions",
          id: subscription_id.to_s,
          attributes: {
            cancelled: false
          }
        }
      })
      response.is_a?(Net::HTTPSuccess)
    rescue StandardError => e
      Rails.logger.error "Lemon Squeezy resume error: #{e.message}"
      false
    end

    def verify_webhook(payload, signature)
      return false if signature.blank?

      secret = webhook_secret
      return false if secret.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    private

    def api_key
      Rails.application.credentials.dig(:lemon_squeezy, :api_key) ||
        ENV["LEMON_SQUEEZY_API_KEY"]
    end

    def store_id
      Rails.application.credentials.dig(:lemon_squeezy, :store_id) ||
        ENV["LEMON_SQUEEZY_STORE_ID"]
    end

    def webhook_secret
      Rails.application.credentials.dig(:lemon_squeezy, :webhook_secret) ||
        ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"]
    end

    def get(path)
      request(:get, path)
    end

    def post(path, body = nil)
      request(:post, path, body)
    end

    def patch(path, body = nil)
      request(:patch, path, body)
    end

    def delete(path)
      request(:delete, path)
    end

    def request(method, path, body = nil)
      uri = URI("#{BASE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = case method
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        Net::HTTP::Post.new(uri)
      when :patch
        Net::HTTP::Patch.new(uri)
      when :delete
        Net::HTTP::Delete.new(uri)
      end

      request["Authorization"] = "Bearer #{api_key}"
      request["Accept"] = "application/vnd.api+json"
      request["Content-Type"] = "application/vnd.api+json"

      if body
        request.body = body.to_json
      end

      http.request(request)
    end
  end
end
