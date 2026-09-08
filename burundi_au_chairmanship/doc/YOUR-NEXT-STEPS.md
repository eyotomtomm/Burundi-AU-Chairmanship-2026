# Your next steps

Updated 2026-09-08. Everything fixable in code is now committed on
`production-readiness-fixes`. This file is the part that needs your hands, in
the order I would do it.

Full findings: `doc/production-readiness-audit-2026-09-03.html`

**Nothing here is optional except section 8.** Sections 1–3 must happen before
the deploy; 4–7 must happen with it.

---

## 0. What was fixed in code — so you know what changes for users

Two of these change what people see on phones that are already installed. That
is what section 3 is about.

| Fix | User-visible? |
|---|---|
| Hidden discussions were readable through the share link | No — closes a moderation bypass |
| Event QR scan returned attendee email + phone to anyone | No — door staff still see them |
| Home feed served draft and archived articles | **Yes — those posts disappear** |
| News/Articles filter backends activated | **Yes — News tab drops 244 → 26** |
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

Rotating the Django secret key logs out all admin sessions. That is expected.

```bash
rm "burundi_au_chairmanship/DIGITALOCEAN_RECOVERY.md"
```

---

## 2. Check migration 0136 against production — before you merge

Migration `0136` was rewritten after it may already have been applied. Re-running
a modified applied migration is how schemas get corrupted. Confirm first:

```bash
# against the PRODUCTION database
python manage.py showmigrations core | grep -E "0135|0136|0137"
```

- **`[X] 0136`** — already applied. Do **not** let it re-run. It is written to be
  idempotent on Postgres (`IF NOT EXISTS`), so this is very likely fine, but
  confirm the `Fact`/`FactCategory` tables and `AppSettings.facts_enabled` exist
  before deploying.
- **`[ ] 0136`** — not applied. Nothing to worry about.

---

## 3. Decide the content sequencing — the one real risk

Today production serves 244 merged articles to the News tab (218 tagged
`article`, 26 tagged `news`), because the filter backends were inactive and the
home feed ignored article status. This branch fixes both at once, so on the
deploy, every one of the ~761 installed phones sees:

- News tab: **244 → 26 items**
- Home: any post saved with the status dropdown set to `draft` or `archived`
  vanishes

Pick one before you deploy:

**(a) Retag first — recommended.** Run this against production *before*
deploying, decide which posts really are news, and fix their `content_type` and
`status` in the admin. Then the deploy is a no-op for readers.

```bash
python manage.py shell -c "
from core.models import Article
from django.db.models import Count
print(Article.objects.values('content_type', 'status').annotate(n=Count('id')).order_by('-n'))
"
```

**(b) Ship backend and store release together.** The old app build does not know
about the new tabs; the drop looks like data loss until the update lands.

**(c) Hold the backend.** Deploy nothing until the store release is approved.

---

## 4. Purge Cloudflare immediately after deploying

Share cards are served with `s-maxage=604800`. Any hidden-discussion card that
was already fetched stays in Cloudflare's edge cache for up to **seven days**
after the fix ships. The code fix does not reach those URLs on its own.

Cloudflare dashboard → your zone → **Caching → Configuration → Purge Everything**
(or purge by prefix `/discussions/`).

---

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

**Redis.** You pay ~$15/month for it while `REDIS_URL` may be unset. If it is
unset, `CELERY_TASK_ALWAYS_EAGER` makes every `.delay()` run inline inside the
web request — which is what makes admin bulk sends time out. Either set
`REDIS_URL` in the app spec, or drop the Redis component and accept that
notifications send synchronously.

```bash
doctl apps spec get <app-id> | grep -A2 REDIS_URL   # after: doctl auth init
```

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

**Verify App Links.** Two fingerprints should be published:

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
