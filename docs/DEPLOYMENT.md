# Deployment & Environment Mapping

## Local Development (Default)

- Hosting: Local Rails server
- Email: letter_opener (or equivalent local mail preview)
- File Storage: Local filesystem (ActiveStorage local)

Notes:
- No external network calls required.
- This is the default mode during development.

---

## Production

- Hosting: Render
- Email: Resend
- File Storage: Cloudflare R2

Notes:
- Production configuration is applied only at deployment time.
- Switching environments must be done via ENV variables.