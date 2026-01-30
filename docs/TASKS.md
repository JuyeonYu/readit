
# task.md

Rule:
- Always implement ONE task at a time
- Stop after task completion
- Do not implement future tasks

# MVP Tasks – readping (읽었어?)

> Goal: 링크를 만들고, 읽히고, 알림이 가는 경험을 완성한다.

---

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

- [ ] T06. 읽기 프리뷰 화면
  - 완료 조건: "읽을까요?" 안내 표시

- [ ] T07. 비밀번호 입력 처리
  - 완료 조건: 비밀번호 있는 경우만 요구

- [ ] T08. 읽기 처리
  - 완료 조건: read_count 증가 + ReadEvent 생성

- [ ] T09. 메시지 내용 표시
  - 완료 조건: 실제 content 노출

---

## Phase 4. Notification (송신자)

- [ ] T10. 읽기 알림 이메일 발송
  - 완료 조건: sender_email로 메일 1통 도착

- [ ] T10-1. 보낸 메시지에 대한 읽음 알림 목록 표시
  - 완료 조건: 읽음에 대한 모든 정보 표시

---

## Phase 5. Edge Cases (안정성)

- [ ] T11. 만료된 메시지 처리
- [ ] T12. 읽기 초과 처리
- [ ] T13. 잘못된 토큰 처리

---

## Phase 6. Release

- [ ] T14. 프로덕션 배포
  - 실서버는 resend로 메일 알림 처리
  - 완료 조건: 실제 도메인에서 플로우 1회 성공

  MVP is complete when:
- A link is created
- The message is read once
- An email notification is delivered