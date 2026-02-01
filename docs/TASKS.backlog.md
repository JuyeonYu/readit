⚠️ This file is NOT part of the active session.

- Read for context only
- NEVER use this to influence current implementation
- NEVER prepare or scaffold for these tasks
- Mentioning backlog tasks during a session is a violation

# task.archive.md

## Phase 1. First Contact (유입 / 이해)

- [o] T01. 랜딩 페이지 생성
  - 완료 조건: 서비스 설명 + "메시지 만들어보기" 버튼 노출

---

## Phase 2. Message Creation (송신자)

- [o] T02. 메시지 입력 화면
  - 완료 조건: 텍스트 입력 가능

- [o] T03. 메시지 옵션 입력
  - 옵션: 만료 / 1회 읽기 / 비밀번호

- [o] T03-1. 로그인
  - 개발서버는 letter_opener 처리


- [o] T04. 메시지 생성 처리
  - 완료 조건: Message 저장 + token 발급

- [o] T05. 공유 링크 화면
  - 완료 조건: /share/:token 접근 가능

---

## Phase 3. Read Flow (수신자)

- [o] T06. 읽기 프리뷰 화면
  - 완료 조건: "읽을까요?" 안내 표시

- [o] T07. 비밀번호 입력 처리
  - 완료 조건: 비밀번호 있는 경우만 요구

- [o] T08. 읽기 처리
  - 완료 조건: read_count 증가 + ReadEvent 생성

- [o] T09. 메시지 내용 표시
  - 완료 조건: 실제 content 노출

---

## Phase 4. Notification (송신자)

- [o] T10. 읽기 알림 이메일 발송
  - 완료 조건: sender_email로 메일 1통 도착

- [o] T10-1. 보낸 메시지 목록 표시
  - 완료 조건: 로그인한 사용자는 렌딩페이지에서 보낸 메시지의 목록을 볼 수 있음. 로그인하지 않고 진입하면 로그인 유도

- [o] T10-2. 보낸 메시지에 대한 읽음 알림 목록 표시
  - 완료 조건: 보낸 메시지 별로 읽음 이벤트 목록 표시

- [o] T10-3. 알림 목록 표시
  - 완료 조건: 로그인한 사용자에게 알림 목록 표시. 로그인하지 않고 진입하면 로그인 유도

---

## Phase 5. Edge Cases (안정성)

- [o] T11. 만료된 메시지 처리
- [o] T12. 읽기 초과 처리
- [o] T13. 잘못된 토큰 처리
- [o] T13-1. 로그아웃