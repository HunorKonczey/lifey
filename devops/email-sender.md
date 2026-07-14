# Email Sender — Resend

Lifey sends transactional email through the **Resend** HTTPS API
(`https://api.resend.com/emails`). SMTP is deliberately avoided: PaaS hosts like
Railway commonly block outbound SMTP ports, and the Resend API goes over 443.

Implementation: `com.lifey.mail` — `ResendMailService` (the sender),
`MailProperties` (config binding), `MailLanguageResolver` (per-recipient
language), `MailTemplateRenderer` (HTML/text templates under
`src/main/resources/mail/`).

## What gets sent

| Trigger | Template | Recipient |
|---|---|---|
| New user registration | `welcome` | the new user |
| Password reset request | `password_reset` | the requesting user |
| Trainer invites a client (if enabled) | `trainer_invite` | the invited client |

Each email is rendered in the recipient's stored language preference
(`UserSettings.language`), falling back to English when unset — Hungarian and
English templates both exist. All sends are async (`mailTaskExecutor` pool) and
failures are caught and logged, never propagated: a bounced email never fails
the request that triggered it.

## Configuration

Bound from `lifey.mail.*` (see `application.yml`). Set these on the **backend**
host (Railway → service → Variables):

| Variable | Default | Purpose |
|---|---|---|
| `MAIL_ENABLED` | `false` | Master switch. When `false`, the sender **logs** what it would send instead of calling Resend — this is the local/dev/CI default. |
| `RESEND_API_KEY` | *(empty)* | Resend API key (`re_...`). Required when `MAIL_ENABLED=true`. |
| `MAIL_FROM` | `onboarding@resend.dev` | The `From:` address. See domain note below. |

> With `MAIL_ENABLED=false` the app runs completely normally — you just see
> `Mail disabled, would have sent '<type>' email to <addr>` in the logs. This is
> the intended state until a Resend account + key exist.

## First-time setup

1. **Create a Resend account** at <https://resend.com> and generate an API key
   (Dashboard → API Keys → Create). Copy it once (`re_...`).
2. **Pick a From address.** Two options:
   - **Quick start (no domain):** keep `MAIL_FROM=onboarding@resend.dev`.
     Resend's shared test domain works with no DNS setup, **but only delivers to
     the email address the Resend account itself signed up with.** Fine for
     smoke-testing, useless for real users.
   - **Production (own domain):** in Resend → Domains, add your domain and create
     the DNS records it shows (SPF `TXT`, DKIM `CNAME`/`TXT`, and a DMARC `TXT`).
     Wait for Resend to mark the domain **Verified**, then set
     `MAIL_FROM=no-reply@yourdomain.com`. Only a verified domain delivers to
     arbitrary recipients and stays out of spam.
3. **Set the backend env vars** (Railway):
   ```
   MAIL_ENABLED=true
   RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxx
   MAIL_FROM=no-reply@yourdomain.com
   ```
4. Redeploy / restart the backend service so it picks up the new vars.

## Verification

1. Trigger a real send: register a new account, or use "forgot password" on the
   web/app with a real inbox you control.
2. Check the mailbox (and spam folder on first sends from a new domain).
3. Cross-check the **Resend dashboard → Emails** log — every attempt shows up
   with a delivered / bounced / complained status.
4. If nothing arrives and the Resend log is empty, check the backend logs:
   - `Mail disabled, would have sent ...` → `MAIL_ENABLED` is still `false`.
   - `Failed to send '<type>' email to ...` (with a stack trace) → bad API key,
     unverified `From` domain, or a Resend API error. The exception message says
     which.

## Routine operations

- **Rotating the API key:** create a new key in Resend, update `RESEND_API_KEY`,
  redeploy, then delete the old key in Resend. No code change.
- **Changing sender address / domain:** verify the new domain first, then update
  `MAIL_FROM`. Never point `MAIL_FROM` at an unverified domain — sends will fail.
- **Deliverability:** keep SPF/DKIM/DMARC records in place; removing them silently
  tanks inbox placement. Monitor bounce/complaint rates in the Resend dashboard.
- **Turning email off in an emergency** (e.g. a send loop): set `MAIL_ENABLED=false`
  and redeploy — the app keeps working, it just stops sending.

## Related

- Trainer-invite email is separately gated by `TRAINER_INVITE_EMAIL_ENABLED`
  (default `false`) and needs `TRAINER_INVITE_PUBLIC_BASE_URL` pointed at the
  backend's own public URL to build the accept/decline links. See `application.yml`.
- Push notifications (a different channel) live in
  [push-notifications-ios.md](push-notifications-ios.md) and
  [push-notifications-android.md](push-notifications-android.md).
