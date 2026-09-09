# Your next steps

Updated 2026-09-09. Everything fixable in code is now committed on
`production-readiness-fixes`. This file is the part that needs your hands, in
the order I would do it.

Full findings: `doc/production-readiness-audit-2026-09-03.html`

**Nothing here is optional except section 8.** Section 1 first, then 2; section
3 goes out with the deploy itself and is the one that keeps the schema intact.
Checked against the live `monkfish-app` spec, not the repo copy.

---

## 0. What was fixed in code — so you know what changes for users

Two of these change what people see on phones that are already installed. That
is what section 3 is about.

| Fix | User-visible? |
|---|---|
| Hidden discussions were readable through the share link | No — closes a moderation bypass |
| Event QR scan returned attendee email + phone to anyone | No — door staff still see them |
| Home feed served draft and archived articles | **Yes — those posts disappear** |
| News and articles merged into one feed | Yes — News now shows everything, on old builds too |
| iOS was missing `NSCalendarsUsageDescription` | No — unblocks App Store upload |
| Tab content ran under the clock and Dynamic Island | Yes, an improvement |
| More page rebuilt: 10 sections → 4, quick actions, verification callout | Yes, an improvement |
| `HeatherGreen` font removed — the file was a 704-byte stub with one empty glyph, so every heading was already falling back | No |
| Build number 2.0.0+57 → +58 | Required for store upload |

---

## 1. Rotate the leaked credentials — do this first

`burundi_au_chairmanship/DIGITALOCEAN_RECOVERY.md` holds five live production
secrets in plaintext. It was never committed and is explicitly gitignored, but it
sits in a synced Downloads folder. Treat all five as compromised.

Rotate each at its source, then update it in the DigitalOcean dashboard
(**Settings → api component → Environment Variables**), then delete the file.

| Secret | Where to rotate |
|---|---|
| `DJANGO_SECRET_KEY` | Generate: `python -c "from django.core.management.utils import get_random_secret_key as k; print(k())"` |
| `DATABASE_URL` password | DigitalOcean → Databases → your cluster → Users → doadmin → Reset password |
| `EMAIL_HOST_PASSWORD` | Google Account → Security → App passwords → revoke the old one, create new |
| `TWILIO_AUTH_TOKEN` | Twilio Console → Account → API keys & tokens → Secondary token → promote & revoke old |
| Firebase service-account key | Firebase Console → Project settings → Service accounts → Generate new private key, then delete the old key in Google Cloud → IAM → Service accounts → Keys |
| `SENTRY_AUTH_TOKEN` | Sentry → Settings → Auth Tokens → revoke `sntrys_…`, issue a new one |

Rotating the Django secret key logs out all admin sessions. That is expected.

**`SENTRY_AUTH_TOKEN` is a sixth one, and it is worse than the others.** In the
live App Platform spec it is stored as a plain env var with no `type: SECRET`,
so its value is readable by anyone who can export the spec — and it was pasted
in cleartext during the 2026-09-09 session. It is an org-scoped token for
`burundi-embassy-pu`. Revoke it in Sentry, issue a new one, and set it in the
dashboard as a **SECRET**; `app_spec_fixed.yaml` already marks the key
`type: SECRET` so App Platform encrypts whatever value it holds on the next
apply. Encrypting the old value does not un-leak it — rotate first.

```bash
rm "burundi_au_chairmanship/DIGITALOCEAN_RECOVERY.md"
```

---

## 2. Check migration 0136 against production — before you merge

Every database operation in `0136` is `IF NOT EXISTS`, so re-running it cannot
corrupt anything — that part of the old warning was overstated. The real risk is
quieter: `0136` repairs a schema whose `Fact` tables were created outside the
migration tracker, and `CREATE TABLE IF NOT EXISTS` **skips silently** if a table
of that name already exists with the wrong columns. The mismatch then survives
the deploy and surfaces as a 500 the first time someone opens Facts.

Run this against the production database. It is read-only and prints a verdict:

```bash
psql "$DATABASE_URL" -f burundi_au_chairmanship/doc/check-0136.sql
```

- **`SAFE - tables do not exist yet`** — nothing to do; `0136` creates them.
- **`SAFE - tables exist with the columns the model expects`** — nothing to do.
- **`REPAIR NEEDED`** — section 3 of the output lists exactly which columns are
  missing. Add them with `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` matching the
  types in `core/migrations/0136_*.py` **before** deploying.

---

## 3. Apply the corrected App Platform spec — do this with the deploy

Production (`monkfish-app`) has drifted from the repo, and four of the
differences matter. A corrected spec is at `~/Downloads/app_spec_fixed.yaml`,
built from the live one you exported, with every encrypted secret preserved:

```bash
doctl auth init                      # you have no token stored yet
doctl apps list                      # find the monkfish-app id
doctl apps update <app-id> --spec ~/Downloads/app_spec_fixed.yaml
```

What it changes, and why each one matters:

**Migrations raced on every deploy.** `entrypoint.sh` runs `migrate` unless
`SKIP_ENTRYPOINT_MIGRATE=1`, the web service runs `instance_count: 2`, and the
live spec had no pre-deploy job — so both containers ran `migrate` at the same
time, every time. The duplicate `0133` row in `django_migrations` is that race
already having happened. Django takes no cross-process lock, so with a long
queue of pending migrations this can half-apply a schema. The fixed spec adds a
`PRE_DEPLOY` job that migrates once, and sets `SKIP_ENTRYPOINT_MIGRATE=1` on the
service. **This is the reason not to deploy the old spec.**

**`SITE_URL` pointed at a dead host.** It was `https://api.burundi4africa.com`,
which returns 404 — `burundi4africa.com` is what serves. Every absolute URL the
backend builds used it, including the unsubscribe link in every newsletter
(`core/tasks.py:325`). Now `https://burundi4africa.com`.

**`EMAIL_BACKEND` was the stock SMTP backend**, not
`core.email_backend.LoggingEmailBackend`. So no `EmailLog` row was written for
any message — Admin → Email Logs has been empty by construction — and the
`FALLBACK_EMAIL_*` vars sitting in the spec were never consulted.

**`SENTRY_PROJECT` was declared twice** on the web service, `b4africa-backend`
then `b4africa-frontend`. The later wins, so backend errors have been filed
under the frontend project. The duplicate is removed.

Not changed, because it is a live-delivery risk and your call: `EMAIL_HOST` is
Gmail with `smtp.burundichairship.africa` as the *fallback*, which is the
inverse of what `.do/app.yaml` intends. Flipping them aligns SPF/DKIM with the
new domain but moves all mail onto an SMTP host that has never carried it.
Decide that deliberately, after the deploy, not during it.
## 4. Cloudflare — you do not need a purge (verified 2026-09-09)

The earlier advice here assumed the edge honoured the `s-maxage=604800` that
`share_card_image` sets, which would have kept a hidden discussion's card alive
for seven days after the fix. Measured against the live zone, it does not:

| URL | `cf-cache-status` |
|---|---|
| `/api/home-feed/`, `/api/articles/` | `DYNAMIC` |
| `/articles/<id>/share/` | `DYNAMIC` |
| `/articles/<id>/card.jpg` | `BYPASS` |
| `/privacy-policy/`, `/.well-known/assetlinks.json` | `DYNAMIC` |
| `/static/...` | `BYPASS` |

Nothing on this zone is served from the Cloudflare cache. `DYNAMIC` means
Cloudflare never considered it cacheable — Django sends `Cache-Control: private`
on almost everything — and `BYPASS` means a rule explicitly skips the cache even
where the origin asked for `public, s-maxage=604800`. So every fix in this
branch is live the moment the deploy finishes, and there is no stale window to
purge.

Purge anyway if you want the reassurance — it costs nothing:
**Cloudflare → your zone → Caching → Configuration → Purge Everything.**

Two things that follow from the same measurement, neither blocking:

**The share cards are not being edge-cached, and they were designed to be.**
Each one is a JPEG rendered by Pillow in the web process. Django keeps a 12-hour
copy (`views.py`, `cache.set(cache_key, jpeg, 60 * 60 * 12)`) so it is not
re-rendered per request, but every crawler and every recipient of a shared link
still reaches origin. That is what `ShareCardThrottle` is defending against, and
it is the reason the throttle exists at all. Find the Cache Rule causing
`BYPASS` and exempt `/*/card.jpg` from it, and those requests stop touching
Django.

**`Cache-Control: private` is coming from Django on everything**, including
`/.well-known/assetlinks.json` and the legal pages. That is Django's default
once a response varies on the session cookie. Harmless, but it means no edge
caching is possible on this zone until it is addressed — worth knowing before
paying for more instances to handle traffic the edge should be absorbing.

## 5. Deploy to staging, not straight to production

The branch is green but has never run against real data or on a device.

```bash
git checkout production-readiness-fixes
# deploy this branch to a staging app first
python manage.py migrate --plan   # review before applying
```

Then on a real device, before you tag a release:

```bash
cd burundi_au_chairmanship
flutter build apk --release   # proves the Android permission removals + adaptive icon
```

That build has never been run since the permission changes. Do it before the
store upload, not after.

---

## 6. Verify email actually sends from the new domain

`.do/app.yaml` sets the primary SMTP host to `smtp.burundichairship.africa` with
Gmail as the fallback. Production may still be running the old values — App
Platform does not pick up spec changes on a plain redeploy.

```bash
doctl apps spec get <app-id> | grep -E "EMAIL_HOST|DEFAULT_FROM_EMAIL"
```

If it still says `smtp.gmail.com`, either apply the spec or set the vars in the
dashboard. Then send one real message from **Admin → Email → Compose** and check
it lands in an inbox, not spam. SPF, DKIM and DMARC must exist for
`burundichairship.africa` or every message soft-fails.

---

## 7. Two decisions and the CI secrets

**Syncfusion PDF viewer licence.** `syncfusion_flutter_pdfviewer` is commercial
with no licence registered. Community Edition is revenue-gated. For a
government-facing app, get this in writing:
https://www.syncfusion.com/sales/teamlicense

**Redis / Celery — largely settled already.** There is no Redis component and
no Celery worker in the live spec, so you are not paying the ~$15/month the old
note claimed. `REDIS_URL` is unset, `CELERY_TASK_ALWAYS_EAGER` is on, and the
`scheduler` worker added in `30dc627` supplies the missing clock by reading
`CELERY_BEAT_SCHEDULE` directly — so scheduled publishing, live-feed status
flips, the newsletter and the news fetch now actually fire.

What remains is only the inline execution: a task triggered by a request still
runs inside that request, which is why admin bulk sends time out. Adding Redis
plus a real Celery worker fixes that and nothing else; the schedules would move
across unchanged, since `run_scheduler` reads the same table.

**CI secrets.** CI runs on push but needs these in **GitHub → Settings → Secrets
and variables → Actions**:

```bash
base64 -i burundi_au_chairmanship/lib/firebase_options.dart | pbcopy            # FIREBASE_OPTIONS_DART_B64
base64 -i burundi_au_chairmanship/android/app/google-services.json | pbcopy     # GOOGLE_SERVICES_JSON_B64
base64 -i burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist | pbcopy  # GOOGLE_SERVICE_INFO_PLIST_B64
base64 -i burundi_au_chairmanship/android/app/upload-keystore.jks | pbcopy      # ANDROID_KEYSTORE_BASE64
```

Plus `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` (from
`android/key.properties`) and `SENTRY_DSN_FLUTTER`.

---

## 8. After the deploy

**Admin 2FA is off.** Login is password-only. Enrol voluntarily at
`/admin/2fa/setup/` any time. To enforce it for every staff user, set
`ADMIN_2FA_REQUIRED=True` in the DigitalOcean dashboard and redeploy. Have an
authenticator app ready first. If you lock yourself out:

```bash
python manage.py shell -c "
from django_otp.plugins.otp_totp.models import TOTPDevice
TOTPDevice.objects.filter(user__username='admin').delete()
print('device cleared - next login re-runs setup')
"
```

**Verify App Links — currently broken in production, fixed by this deploy.**
`/.well-known/assetlinks.json` serves exactly one fingerprint today, the upload
key `2E:76:17:…`. Play-installed builds are signed with the *Play App Signing*
key, so Android's verification fails against that file and shared links open in
the browser instead of the app for every Play Store user. Both fingerprints are
already in `config/urls.py` on this branch; they reach production when it
deploys. Confirm two are served, then re-verify on a device:

```bash
curl -s https://burundi4africa.com/.well-known/assetlinks.json | python3 -m json.tool
adb shell pm verify-app-links --re-verify com.b4africa.app
adb shell pm get-app-links com.b4africa.app     # want: verified
```

**Not blocking, worth doing.** Run the k6 smoke profile in `load_tests/` against
staging (never the full 40k ramp — one worker will not survive it). Decide which
of the ~54 root `.md` files to keep now that the blanket `*.md` ignore is gone.
Make sure your Play Data Safety form reflects `AD_ID` and `ACCESS_ADSERVICES_*`,
which Firebase Analytics pulls in. Test coverage is thin — 112 backend tests for
a 45-model app, with OTP flows, verification badges, support tickets and
notification targeting all untested.
