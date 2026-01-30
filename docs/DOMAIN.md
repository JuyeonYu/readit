# Domain Model - 읽었어? (readping)

> Rails 8 + Ruby 4 기반 심플 설계

## 주요 모델 (Active Record)

### Message
```ruby
# app/models/message.rb
class Message < ApplicationRecord
  has_many :read_events, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :token, presence: true, uniqueness: true
  validates :content, presence: true
  validates :expires_at, comparison: { greater_than: -> { Time.current } }, 
            if: -> { expires_at.present? && will_save_change_to_expires_at? }
  validates :password, length: { minimum: 6 }, allow_blank: true
  
  before_validation :generate_token, on: :create
  
  # 비밀번호 해시 (has_secure_password 사용)
  has_secure_password validations: false
  
  private
  
  def generate_token
    return if token.present?
    
    # 충돌 시 재시도 (최대 10회)
    10.times do
      self.token = SecureRandom.urlsafe_base64(24)
      return unless Message.exists?(token: token)
    end
    
    # 10회 모두 실패 시 명시적 에러
    errors.add(:token, "could not be generated")
  end
end
```

**테이블: messages**
```ruby
- id (bigint, PK)
- token (string, unique, indexed) # URL 토큰 (~32자)
- content (text) # 메시지 내용
- sender_email (string, nullable) # 알림용
- password_digest (string, nullable) # has_secure_password
- max_read_count (integer, nullable) # null = 무제한
- expires_at (datetime, nullable)
- read_count (integer, default: 0) # with_lock으로 증가
- is_active (boolean, default: true)
- created_at (datetime)
- updated_at (datetime)
```

**책임**
- 콘텐츠 저장
- 토큰 생성 (before_validation, 충돌 시 재시도)
- 읽기 가능 여부 검증

**주요 메서드**
```ruby
def readable?
  is_active &&
    (expires_at.nil? || expires_at.future?) &&
    (max_read_count.nil? || read_count < max_read_count)
end

# with_lock 내에서만 호출
def increment_read_count!
  increment!(:read_count)
end
```

---

### ReadEvent
```ruby
# app/models/read_event.rb
class ReadEvent < ApplicationRecord
  belongs_to :message
  
  validates :message_id, presence: true
end
```

**테이블: read_events**
```ruby
- id (bigint, PK)
- message_id (bigint, FK, indexed)
- read_at (datetime, default: -> { 'CURRENT_TIMESTAMP' })
- user_agent (string, nullable) # 통계용
- viewer_token_hash (string, nullable, indexed) # 쿠키 토큰의 해시값
- created_at (datetime)
- updated_at (datetime)
```

**책임**
- 읽기 이벤트 기록
- 뷰어 토큰 해시 저장 (개인정보 보호)

**제약**
- IP 저장 안함
- user_agent 최소 수집
- viewer_token_hash는 이미 해시된 값만 저장 (컨트롤러에서 해시 처리)
- 알림 트리거는 Service에서만 처리 (callback 없음)

---

### Notification
```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :message
  
  enum status: { pending: 0, sent: 1, failed: 2 }
  enum notification_type: { email: 0, web: 1, slack: 2, webhook: 3 }
  
  validates :message_id, :recipient, :notification_type, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
end
```

**테이블: notifications**
```ruby
- id (bigint, PK)
- message_id (bigint, FK, indexed)
- notification_type (integer, default: 0) # enum
- recipient (string) # 이메일 주소 (스냅샷)
- status (integer, default: 0) # enum
- idempotency_key (string, unique, indexed) # 중복 방지
- sent_at (datetime, nullable)
- created_at (datetime)
- updated_at (datetime)
```

**책임**
- 알림 발송 상태 관리
- 중복 알림 방지 (idempotency_key)

**제약**
- MVP는 email만
- idempotency_key로 동시 Job 실행 시 중복 방지

---

## 관계

```
Message 1 ──────< ReadEvent
   │
   └──────< Notification
```

- **has_many :read_events** (counter_cache 사용 안함)
- **has_many :notifications**
- **belongs_to :message**

---

## 비즈니스 로직

### 1. 메시지 생성 (Controller)
```ruby
# app/controllers/messages_controller.rb
def create
  @message = Message.new(message_params)
  
  if @message.save
    redirect_to share_message_path(@message.token)
  else
    render :new, status: :unprocessable_entity
  end
end

private

def message_params
  params.require(:message).permit(
    :content, :sender_email, :password, 
    :max_read_count, :expires_at
  )
end
```

### 2. 메시지 읽기 (Controller)
```ruby
# app/controllers/reads_controller.rb
def show
  @message = Message.find_by!(token: params[:token])
  
  unless @message.readable?
    redirect_to expired_path
  end
  
  # 프리뷰 화면
end

def create
  @message = Message.find_by!(token: params[:token])
  
  # 비밀번호 확인
  if @message.password_digest.present?
    unless @message.authenticate(params[:password])
      redirect_to read_path(@message.token), alert: "비밀번호 오류"
      return
    end
  end
  
  # 읽기 처리 (Service)
  viewer_token = cookies.signed[:viewer_token] ||= SecureRandom.hex(32)
  
  result = ReadMessageService.call(
    @message, 
    viewer_token_hash: Digest::SHA256.hexdigest(viewer_token),
    user_agent: request.user_agent
  )
  
  if result.success?
    render :content
  else
    redirect_to read_path(@message.token), alert: result.error
  end
end
```

### 3. 읽기 처리 Service (트랜잭션 + 락)
```ruby
# app/services/read_message_service.rb
class ReadMessageService
  Result = Struct.new(:success?, :read_event, :error, keyword_init: true)
  
  def self.call(message, viewer_token_hash:, user_agent: nil)
    read_event = nil
    
    # 트랜잭션 + 락으로 동시성 제어
    ActiveRecord::Base.transaction do
      message.with_lock do
        # 읽기 가능 여부 재검증 (락 내에서)
        unless message.readable?
          return Result.new(success?: false, error: "더 이상 읽을 수 없습니다")
        end
        
        # read_count 증가
        message.increment_read_count!
        
        # 읽기 이벤트 생성
        read_event = message.read_events.create!(
          viewer_token_hash: viewer_token_hash,
          user_agent: user_agent,
          read_at: Time.current
        )
      end
    end
    
    # 알림 발송 (비동기, 트랜잭션 밖)
    if message.sender_email.present?
      SendNotificationJob.perform_later(message.id)
    end
    
    Result.new(success?: true, read_event: read_event)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, error: e.message)
  end
end
```

### 4. 알림 Job (중복 방지)
```ruby
# app/jobs/send_notification_job.rb
class SendNotificationJob < ApplicationJob
  queue_as :default
  
  def perform(message_id)
    message = Message.find(message_id)
    return unless message.sender_email.present?
    
    # idempotency_key 생성 (5분 버킷)
    bucket = (Time.current.to_i / 300) * 300
    idempotency_key = "message:#{message_id}:email:#{bucket}"
    
    # 중복 방지 (find_or_create_by)
    notification = message.notifications.find_or_create_by!(
      idempotency_key: idempotency_key
    ) do |n|
      n.notification_type = :email
      n.recipient = message.sender_email
      n.status = :pending
    end
    
    # 이미 발송됐으면 skip
    return if notification.sent?
    
    # 메일 발송
    begin
      MessageMailer.read_notification(message).deliver_now
      notification.update!(status: :sent, sent_at: Time.current)
    rescue => e
      notification.update!(status: :failed)
      raise
    end
  end
end
```

---

## 마이그레이션

```ruby
# db/migrate/xxx_create_messages.rb
class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.string :token, null: false, index: { unique: true }
      t.text :content, null: false
      t.string :sender_email
      t.string :password_digest
      t.integer :max_read_count
      t.datetime :expires_at
      t.integer :read_count, default: 0, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :messages, :expires_at
    add_index :messages, :created_at
  end
end

# db/migrate/xxx_create_read_events.rb
class CreateReadEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :read_events do |t|
      t.references :message, null: false, foreign_key: true
      t.datetime :read_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :user_agent
      t.string :viewer_token_hash # SHA256 해시값

      t.timestamps
    end
    
    add_index :read_events, :viewer_token_hash
    add_index :read_events, :read_at
  end
end

# db/migrate/xxx_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :message, null: false, foreign_key: true
      t.integer :notification_type, default: 0, null: false
      t.string :recipient, null: false
      t.integer :status, default: 0, null: false
      t.string :idempotency_key, null: false, index: { unique: true }
      t.datetime :sent_at

      t.timestamps
    end
    
    add_index :notifications, [:message_id, :status]
    add_index :notifications, :sent_at
  end
end
```

---

## 라우팅

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :messages, only: [:new, :create]
  
  get '/read/:token', to: 'reads#show', as: :read_message
  post '/read/:token', to: 'reads#create', as: :read_content
  
  get '/share/:token', to: 'messages#share', as: :share_message
end
```

---

## 핵심 원칙 (from ARCH.md & RULES.md)

✅ **Controller thin** - 비즈니스 로직 최소화  
✅ **Service only if needed** - 복잡한 경우만 Service 사용  
✅ **No over-abstraction** - Rails 기본 기능 활용  
✅ **Prefer simple Rails way** - ActiveRecord, validation 적극 활용

---

## 동시성 제어 전략

### 읽기 제한 (max_read_count) 보장
```ruby
# with_lock으로 원자적 제어
message.with_lock do
  return false unless message.readable?
  message.increment_read_count!
  message.read_events.create!(...)
end
```

### 알림 중복 방지
```ruby
# idempotency_key로 중복 Job 실행 시에도 1개만 생성
notification = message.notifications.find_or_create_by!(
  idempotency_key: "message:#{id}:email:#{time_bucket}"
)
```

---

## 테스트 전략

```ruby
# test/models/message_test.rb
test "readable? returns false when expired" do
  message = messages(:expired)
  assert_not message.readable?
end

test "readable? returns false when max_read_count exceeded" do
  message = messages(:one_time)
  message.update!(read_count: 1, max_read_count: 1)
  assert_not message.readable?
end

# test/services/read_message_service_test.rb
test "prevents concurrent reads beyond max_read_count" do
  message = messages(:one_time)
  message.update!(max_read_count: 1)
  
  threads = 3.times.map do
    Thread.new do
      token = SecureRandom.hex(32)
      ReadMessageService.call(message, viewer_token_hash: Digest::SHA256.hexdigest(token))
    end
  end
  
  results = threads.map(&:value)
  success_count = results.count(&:success?)
  
  assert_equal 1, success_count, "Only 1 read should succeed"
  assert_equal 1, message.reload.read_count
end

test "prevents duplicate notifications within 5 minutes" do
  message = messages(:with_sender)
  
  assert_difference -> { Notification.count } => 1 do
    2.times { SendNotificationJob.perform_now(message.id) }
  end
end
```

---

## 개선 사항 요약

### 🔒 동시성 제어
- ❌ `counter_cache` 제거 (경합 상황 취약)
- ✅ `with_lock` + 트랜잭션으로 원자적 제어

### 🔔 알림 처리
- ❌ `after_create` callback 제거 (중복 트리거)
- ✅ Service에서만 Job enqueue
- ✅ `idempotency_key`로 중복 방지

### 🔐 보안
- ✅ `viewer_token_hash` - 컨트롤러에서 SHA256 해시 처리 (모델은 해시값만 받음)
- ✅ `generate_token` - 충돌 재시도
- ✅ `password` - 최소 6자 validation

### 🛡️ 안정성
- ✅ `user_agent`를 파라미터로 전달 (Service에서 request 접근 불가)
- ✅ `notification` 먼저 생성 후 메일 발송
- ✅ `expires_at` 생성/변경 시에만 미래 시각 validation (다른 필드 업데이트 방해 안함)

---

## Post-MVP 확장

### User 모델 추가 시
```ruby
class User < ApplicationRecord
  has_many :messages, foreign_key: :owner_id
end

# messages 테이블에 owner_id 추가
add_reference :messages, :owner, foreign_key: { to_table: :users }
```

**MVP 내구성 확보. 운영 가능한 설계 완성.** ✅
