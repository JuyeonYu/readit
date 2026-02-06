class SendWebhookJob < ApplicationJob
  queue_as :default

  def perform(message_id, viewer_token_hash)
    message = Message.find(message_id)
    user = message.user

    return unless user.pro?
    return unless user.webhook_url.present?

    # Generate idempotency_key (once per unique viewer per webhook)
    idempotency_key = "webhook:message:#{message_id}:viewer:#{viewer_token_hash}"

    # Prevent duplicates
    notification = message.notifications.find_or_create_by!(
      idempotency_key: idempotency_key
    ) do |n|
      n.notification_type = :webhook
      n.recipient = user.webhook_url
      n.status = :pending
    end

    # Skip if already sent
    return if notification.sent?

    # Send webhook
    begin
      response = send_webhook(user.webhook_url, build_payload(message, user.webhook_url))

      if response.is_a?(Net::HTTPSuccess)
        notification.update!(status: :sent, sent_at: Time.current)
      else
        notification.update!(status: :failed)
        Rails.logger.error("Webhook failed for message #{message_id}: #{response.code} #{response.message}")
      end
    rescue => e
      notification.update!(status: :failed)
      Rails.logger.error("Webhook error for message #{message_id}: #{e.message}")
    end
  end

  private

  def build_payload(message, url)
    if discord_webhook?(url)
      build_discord_payload(message)
    elsif slack_webhook?(url)
      build_slack_payload(message)
    elsif teams_webhook?(url)
      build_teams_payload(message)
    elsif telegram_webhook?(url)
      build_telegram_payload(message)
    else
      build_generic_payload(message)
    end
  end

  def discord_webhook?(url)
    url.include?("discord.com/api/webhooks") || url.include?("discordapp.com/api/webhooks")
  end

  def slack_webhook?(url)
    url.include?("hooks.slack.com/services")
  end

  def teams_webhook?(url)
    url.include?("webhook.office.com") || url.include?("outlook.office.com/webhook")
  end

  def telegram_webhook?(url)
    url.include?("api.telegram.org/bot")
  end

  def build_discord_payload(message)
    share_url = Rails.application.routes.url_helpers.share_message_url(message.token, host: default_host)

    {
      embeds: [
        {
          title: "Message Opened",
          description: "Your message \"**#{message.title}**\" was just read!",
          color: 5025616,  # Green color
          fields: [
            {
              name: "Total Opens",
              value: message.read_count.to_s,
              inline: true
            },
            {
              name: "Created",
              value: message.created_at.strftime("%Y-%m-%d %H:%M"),
              inline: true
            }
          ],
          url: share_url,
          footer: {
            text: "MessageOpen"
          },
          timestamp: Time.current.iso8601
        }
      ]
    }
  end

  def build_teams_payload(message)
    share_url = Rails.application.routes.url_helpers.share_message_url(message.token, host: default_host)

    {
      "@type": "MessageCard",
      "@context": "http://schema.org/extensions",
      themeColor: "4CA154",
      summary: "Message Opened",
      sections: [
        {
          activityTitle: "Message Opened",
          activitySubtitle: "MessageOpen Notification",
          facts: [
            { name: "Message", value: message.title },
            { name: "Total Opens", value: message.read_count.to_s },
            { name: "Created", value: message.created_at.strftime("%Y-%m-%d %H:%M") }
          ],
          markdown: true
        }
      ],
      potentialAction: [
        {
          "@type": "OpenUri",
          name: "View Details",
          targets: [
            { os: "default", uri: share_url }
          ]
        }
      ]
    }
  end

  def build_telegram_payload(message)
    share_url = Rails.application.routes.url_helpers.share_message_url(message.token, host: default_host)

    {
      text: "📬 *Message Opened*\n\nYour message \"*#{message.title}*\" was just read\\!\n\n📊 Total Opens: #{message.read_count}\n📅 Created: #{message.created_at.strftime('%Y-%m-%d %H:%M')}\n\n[View Details](#{share_url})",
      parse_mode: "MarkdownV2",
      disable_web_page_preview: false
    }
  end

  def build_slack_payload(message)
    share_url = Rails.application.routes.url_helpers.share_message_url(message.token, host: default_host)

    {
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "Message Opened",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "Your message *#{message.title}* was just read!"
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Total Opens:*\n#{message.read_count}"
            },
            {
              type: "mrkdwn",
              text: "*Created:*\n#{message.created_at.strftime('%Y-%m-%d %H:%M')}"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "View Details",
                emoji: true
              },
              url: share_url
            }
          ]
        },
        {
          type: "context",
          elements: [
            {
              type: "plain_text",
              text: "MessageOpen",
              emoji: true
            }
          ]
        }
      ]
    }
  end

  def build_generic_payload(message)
    {
      event: "message.read",
      timestamp: Time.current.iso8601,
      data: {
        message_id: message.token,
        title: message.title,
        read_count: message.read_count,
        created_at: message.created_at.iso8601,
        url: Rails.application.routes.url_helpers.share_message_url(message.token, host: default_host)
      }
    }
  end

  def send_webhook(url, payload)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "MessageOpen-Webhook/1.0"
    request.body = payload.to_json

    http.request(request)
  end

  def default_host
    Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000"
  end
end
