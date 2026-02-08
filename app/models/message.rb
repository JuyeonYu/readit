class Message < ApplicationRecord
  TITLE_MAX_LENGTH = 50
  CONTENT_MAX_LENGTH = 10_000
  ATTACHMENT_MAX_SIZE = 5.megabytes
  ATTACHMENT_TOTAL_MAX_SIZE = 20.megabytes
  ATTACHMENT_ALLOWED_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  belongs_to :user
  has_many :read_events, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_rich_text :content

  has_secure_password validations: false

  validates :token, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :content, presence: true
  validate :content_length_within_limit
  validate :attachments_within_limits
  validates :expires_at, comparison: { greater_than: -> { Time.current } },
            if: -> { expires_at.present? && will_save_change_to_expires_at? }
  validates :password, length: { minimum: 6 }, allow_blank: true
  validate :password_requires_pro

  before_validation :generate_token, on: :create

  def sender_email
    user&.email
  end

  def readable?
    is_active &&
      (expires_at.nil? || expires_at.future?) &&
      (max_read_count.nil? || read_count < max_read_count)
  end

  def increment_read_count!
    increment!(:read_count)
  end

  def unique_reader_count
    read_events.distinct.count(:viewer_token_hash)
  end

  # Returns grouped read events with optional limit on number of viewers
  # Each viewer gets up to 3 most recent events
  # Returns: { viewers: [[hash, events], ...], total_viewers: count, has_more: boolean }
  def grouped_reads(limit: nil)
    # Use window functions to efficiently fetch only recent events per viewer
    # This avoids loading all read_events into memory
    sql = <<-SQL
      SELECT * FROM (
        SELECT read_events.*,
               ROW_NUMBER() OVER (PARTITION BY viewer_token_hash ORDER BY read_at DESC) as rn,
               COUNT(*) OVER (PARTITION BY viewer_token_hash) as view_count,
               MIN(read_at) OVER (PARTITION BY viewer_token_hash) as first_read_at
        FROM read_events
        WHERE message_id = ?
      ) ranked
      WHERE rn <= 3
      ORDER BY first_read_at DESC, read_at ASC
    SQL

    events = ReadEvent.find_by_sql([sql, id])

    # Group by viewer and sort by first read time (newest first)
    grouped = events.group_by(&:viewer_token_hash).map do |viewer_hash, viewer_events|
      [viewer_hash, viewer_events.sort_by(&:read_at)]
    end

    total_viewers = grouped.size

    # Apply limit if specified
    if limit && grouped.size > limit
      grouped = grouped.first(limit)
      has_more = true
    else
      has_more = false
    end

    { viewers: grouped, total_viewers: total_viewers, has_more: has_more }
  end

  # Memoized helper to get first image attachment (avoids repeated parsing)
  def first_image_attachment
    return @first_image_attachment if defined?(@first_image_attachment)
    return @first_image_attachment = nil if content.blank? || content.body.blank?

    @first_image_attachment = content.body.attachments.find do |a|
      a.attachable.is_a?(ActiveStorage::Blob) && a.attachable.image?
    end
  end

  # Memoized helper to get plain text preview (avoids repeated parsing)
  def plain_text_preview(length: 150)
    return "" if content.blank? || content.body.blank?

    @plain_text_cache ||= content.body.to_plain_text.strip
    @plain_text_cache.truncate(length)
  end

  def reactions_summary
    read_events.where.not(reaction: nil).group(:reaction).count
  end

  def total_reactions_count
    read_events.where.not(reaction: nil).count
  end

  def content_length
    content.body.to_plain_text.length
  end

  private

  def content_length_within_limit
    return if content.blank?

    if content.body.to_plain_text.length > CONTENT_MAX_LENGTH
      errors.add(:content, :too_long, count: CONTENT_MAX_LENGTH)
    end
  end

  def attachments_within_limits
    return if content.blank?

    attachments = content.body.attachments
    return if attachments.empty?

    total_size = 0

    attachments.each do |attachment|
      blob = attachment.attachable
      next unless blob.is_a?(ActiveStorage::Blob)

      # Check individual file size
      if blob.byte_size > ATTACHMENT_MAX_SIZE
        errors.add(:content, :attachment_too_large, filename: blob.filename, max_size: ATTACHMENT_MAX_SIZE / 1.megabyte)
        next
      end

      # Check file type
      unless ATTACHMENT_ALLOWED_TYPES.include?(blob.content_type)
        errors.add(:content, :attachment_invalid_type, filename: blob.filename)
        next
      end

      total_size += blob.byte_size
    end

    # Check total size
    if total_size > ATTACHMENT_TOTAL_MAX_SIZE
      errors.add(:content, :attachments_total_too_large, max_size: ATTACHMENT_TOTAL_MAX_SIZE / 1.megabyte)
    end
  end

  def generate_token
    return if token.present?

    10.times do
      self.token = SecureRandom.urlsafe_base64(24)
      return unless Message.exists?(token: token)
    end

    errors.add(:token, "could not be generated")
  end

  def password_requires_pro
    return unless password.present? && user.present? && !user.pro?

    errors.add(:password, :pro_only)
  end
end
