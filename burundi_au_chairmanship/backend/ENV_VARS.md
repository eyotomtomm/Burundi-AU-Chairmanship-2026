# Backend environment variables

Every variable read by `config/settings.py` (plus `config/urls.py`,
`config/firebase.py`, `gunicorn.conf.py`). Locally they come from
`backend/.env` (python-dotenv); in production from App Platform
(`.do/app.yaml` + dashboard secrets). Booleans accept `true/1/yes`.

## Core (required in production)

| Var | Required | Default | Purpose |
|---|---|---|---|
| `DJANGO_SECRET_KEY` | **yes** (always) | — | Django signing key; process refuses to start without it. |
| `DJANGO_DEBUG` | no | `False` | Debug mode. Also switches SQLite/local media/console email vs. production backends. |
| `DJANGO_ALLOWED_HOSTS` | prod | `''` | Comma-separated hosts (apex, www, api, DO app domain). |
| `DATABASE_URL` | prod | — (SQLite) | PostgreSQL DSN. Parsed with `conn_max_age=0` for pgbouncer. |
| `READ_REPLICA_URL` | no | `''` | Optional PostgreSQL read replica DSN (`DATABASES['replica']`). |
| `REDIS_URL` | prod | `''` | Cache, Celery broker/result and Channels layer. Without it: DB cache, eager Celery, in-memory channels. |
| `SITE_URL` | no | `http://127.0.0.1:8000` (debug) / `https://burundi4africa.com` | Absolute base for media/push/share URLs. |

## Media storage (DigitalOcean Spaces, used when `DJANGO_DEBUG=False`)

| Var | Required | Default | Purpose |
|---|---|---|---|
| `DO_SPACES_KEY` | prod | `''` | Spaces access key. |
| `DO_SPACES_SECRET` | prod | `''` | Spaces secret key. |
| `DO_SPACES_BUCKET` | prod | `''` | Bucket name (`burundi-au-media`). |
| `DO_SPACES_ENDPOINT` | prod | `''` | `https://fra1.digitaloceanspaces.com`. |
| `CDN_DOMAIN` | no | `''` | Spaces CDN host; rewrites public `MEDIA_URL`. Private media always signs against the origin. |
| `MAX_VIDEO_SIZE_MB` | no | `200` | Upload cap for progressive MP4. |

## Email

| Var | Required | Default | Purpose |
|---|---|---|---|
| `EMAIL_BACKEND` | no | `core.email_backend.LoggingEmailBackend` (prod) | Set to `django.core.mail.backends.smtp.EmailBackend` in prod. |
| `EMAIL_HOST` / `EMAIL_PORT` | no | `smtp.gmail.com` / `587` | Primary SMTP (OTP + system mail). |
| `EMAIL_USE_TLS` / `EMAIL_USE_SSL` | no | `True` / `False` | Primary SMTP transport. |
| `EMAIL_HOST_USER` / `EMAIL_HOST_PASSWORD` | prod | `''` | Primary SMTP credentials (secret). |
| `DEFAULT_FROM_EMAIL` | no | `Be 4 Africa <info@burundi4africa.com>` | From header. |
| `FALLBACK_EMAIL_HOST` / `_PORT` / `_USE_TLS` / `_USE_SSL` | no | `smtp.burundichairship.africa` / `465` / `False` / `True` | Retry SMTP when primary fails. |
| `FALLBACK_EMAIL_HOST_USER` / `FALLBACK_EMAIL_HOST_PASSWORD` | no | `info@burundichairship.africa` / `''` | Fallback credentials. |
| `FALLBACK_FROM_EMAIL` | no | `Be 4 Africa <info@burundichairship.africa>` | Fallback From header. |
| `CAMPAIGN_EMAIL_HOST` / `_PORT` / `_USE_TLS` / `_USE_SSL` | no | `smtp.burundichairship.africa` / `465` / `False` / `True` | Newsletter/campaign SMTP. |
| `CAMPAIGN_EMAIL_HOST_USER` / `CAMPAIGN_EMAIL_HOST_PASSWORD` | no | `newsletter@burundichairship.africa` / `''` | Campaign credentials; campaigns silently don't send without the password. |
| `CAMPAIGN_FROM_EMAIL` | no | `Be 4 Africa <newsletter@burundichairship.africa>` | Campaign From header. |
| `IMAP_HOST` / `IMAP_PORT` / `IMAP_USE_SSL` / `IMAP_MAILBOX` | no | `imap.gmail.com` / `993` / `True` / `INBOX` | Admin "Email Inbox" viewer. |
| `IMAP_USER` / `IMAP_PASSWORD` | no | = `EMAIL_HOST_USER` / `EMAIL_HOST_PASSWORD` | IMAP credentials. |

## Observability (Sentry)

| Var | Required | Default | Purpose |
|---|---|---|---|
| `SENTRY_DSN` | no | `''` | Enables Sentry when set. |
| `SENTRY_ENVIRONMENT` | no | `development`/`production` by DEBUG | Environment tag. |
| `SENTRY_RELEASE` | no | derived | Release tag. If unset, built from `GIT_SHA`; else `burundi-au-backend@1.0.0`. app.yaml binds `${_self.COMMIT_HASH}`. |
| `GIT_SHA` | no | — | Fallback source for the release tag. |
| `SENTRY_TRACES_SAMPLE_RATE` / `SENTRY_PROFILES_SAMPLE_RATE` | no | `0.2` / `0.1` | Performance sampling. |
| `SENTRY_SERVER_NAME` | no | `''` | server_name tag. |
| `SENTRY_AUTH_TOKEN` / `SENTRY_ORG` / `SENTRY_PROJECT` / `SENTRY_API_BASE` | no | `''` / `''` / `''` / `https://de.sentry.io/api/0` | Admin-portal Sentry issue browser (API calls). |

## Background jobs

| Var | Required | Default | Purpose |
|---|---|---|---|
| `CELERY_BROKER_URL` | no | `REDIS_URL` or `redis://localhost:6379/1` | Celery broker. |
| `CELERY_RESULT_BACKEND` | no | `REDIS_URL` or `redis://localhost:6379/2` | Celery results. |
| `WEB_CONCURRENCY` | no | `1` | Gunicorn worker count (`gunicorn.conf.py`). professional-xs fits one. |
| `SKIP_ENTRYPOINT_MIGRATE` | no | — | `1` skips migrate/collectstatic in `entrypoint.sh` (they run in the PRE_DEPLOY job). |

## Integrations (optional; feature degrades when unset)

| Var | Default | Purpose |
|---|---|---|
| `FIREBASE_CREDENTIALS_JSON` | `''` | Firebase Admin service-account JSON (push notifications, token verification). |
| `FIREBASE_CREDENTIALS_PATH` | `config/firebase-adminsdk.json` | File fallback for the above. |
| `WEATHERAPI_KEY` | `''` | WeatherAPI.com key for the weather widget. |
| `GEMINI_API_KEY` | `''` | Gemini for AI translation. |
| `RECAPTCHA_SECRET_KEY` / `RECAPTCHA_SITE_KEY` | `''` | Server-side reCAPTCHA on registration (skipped when unset). |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_PHONE_NUMBER` | `''` | Phone OTP for verification badges. |
| `ANDROID_PLAY_SIGNING_SHA256` | `''` | Comma-separated Play App Signing cert SHA-256(s) added to `assetlinks.json` (`config/urls.py`). |
