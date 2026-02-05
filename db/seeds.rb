# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Demo data for screenshots (only for remake382@gmail.com)
demo_email = "remake382@gmail.com"

user = User.find_or_create_by!(email: demo_email) do |u|
  u.plan = "pro"
  u.subscription_status = "active"
  u.current_period_end = 1.year.from_now
end

puts "Created/found user: #{user.email}"

# Clear existing messages for this user (for clean re-seeding)
user.messages.destroy_all

# Helper to create ActionText content
def rich_content(text)
  ActionText::Content.new(text)
end

# Message 1: Popular proposal - many readers
msg1 = user.messages.create!(
  title: "Q1 2025 Marketing Proposal - Acme Corp",
  content: rich_content("<p>Hi Sarah,</p><p>Please find attached our comprehensive marketing strategy for Q1 2025. This proposal includes:</p><ul><li>Social media campaign timeline</li><li>Budget breakdown</li><li>Expected ROI projections</li></ul><p>Let me know if you have any questions!</p><p>Best regards</p>"),
  created_at: 3.days.ago,
  read_count: 5
)

# Add read events for msg1
5.times do |i|
  msg1.read_events.create!(
    viewer_token_hash: SecureRandom.hex(16),
    read_at: (3.days.ago + (i * 4).hours),
    user_agent: ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"].sample
  )
end

puts "Created message: #{msg1.title}"

# Message 2: Password protected contract
msg2 = user.messages.create!(
  title: "Service Agreement - Confidential",
  content: rich_content("<p>Dear Client,</p><p>This document contains our confidential service agreement terms. Please review carefully before signing.</p><p>Contact me if you need any clarifications.</p>"),
  password: "secure123",
  created_at: 2.days.ago,
  read_count: 2
)

2.times do |i|
  msg2.read_events.create!(
    viewer_token_hash: SecureRandom.hex(16),
    read_at: (2.days.ago + (i * 6).hours),
    user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
  )
end

puts "Created message: #{msg2.title} (password protected)"

# Message 3: Expiring soon
msg3 = user.messages.create!(
  title: "Interview Details - Frontend Developer Position",
  content: rich_content("<p>Hello!</p><p>Thank you for your application. We'd like to invite you for an interview.</p><p><strong>Date:</strong> Next Monday at 2:00 PM<br><strong>Location:</strong> Zoom (link will be sent separately)</p><p>Please confirm your availability.</p>"),
  expires_at: 2.days.from_now,
  created_at: 1.day.ago,
  read_count: 1
)

msg3.read_events.create!(
  viewer_token_hash: SecureRandom.hex(16),
  read_at: 12.hours.ago,
  user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)"
)

puts "Created message: #{msg3.title} (expires in 2 days)"

# Message 4: One-time read (max_read_count = 1)
msg4 = user.messages.create!(
  title: "Offer Letter - Senior Product Manager",
  content: rich_content("<p>Dear Candidate,</p><p>We are pleased to extend an offer of employment for the position of Senior Product Manager.</p><p><strong>Salary:</strong> $150,000/year<br><strong>Start Date:</strong> March 1, 2025</p><p>Please review and let us know your decision within 7 days.</p>"),
  max_read_count: 1,
  created_at: 4.hours.ago,
  read_count: 0
)

puts "Created message: #{msg4.title} (one-time read)"

# Message 5: Recently sent, unread
msg5 = user.messages.create!(
  title: "Project Update - Mobile App Launch",
  content: rich_content("<p>Team,</p><p>Quick update on our mobile app launch timeline:</p><ul><li>Beta testing: Complete ✓</li><li>App Store submission: This Friday</li><li>Expected launch: Feb 15, 2025</li></ul><p>Great work everyone!</p>"),
  created_at: 30.minutes.ago,
  read_count: 0
)

puts "Created message: #{msg5.title} (unread)"

# Message 6: Expired message (skip validation for past expires_at)
msg6 = user.messages.new(
  title: "Flash Sale Announcement - 24hr Only",
  content: rich_content("<p>🎉 Flash Sale!</p><p>Get 50% off all products for the next 24 hours only.</p><p>Use code: FLASH50</p>"),
  token: SecureRandom.urlsafe_base64(24),
  expires_at: 1.day.ago,
  created_at: 3.days.ago,
  read_count: 12
)
msg6.save!(validate: false)

12.times do |i|
  msg6.read_events.create!(
    viewer_token_hash: SecureRandom.hex(16),
    read_at: (3.days.ago + (i * 2).hours),
    user_agent: ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)", "Mozilla/5.0 (Linux; Android 13)"].sample
  )
end

puts "Created message: #{msg6.title} (expired)"

puts "\n✅ Demo data created successfully for #{demo_email}!"
puts "   - #{user.messages.count} messages"
puts "   - #{ReadEvent.joins(:message).where(messages: { user_id: user.id }).count} read events"
