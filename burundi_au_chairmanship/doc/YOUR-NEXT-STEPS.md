# Your next steps

Everything fixable in code is committed on `production-readiness-fixes`
(2 commits, 384 files). This file is the part that needs your hands, in order.

Full findings: `doc/production-readiness-audit-2026-09-03.html`

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

Then:

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

## 3. Deploy to staging, not straight to production

The branch is green but has never run against real data or on a device.

```bash
git checkout production-readiness-fixes
# deploy this branch to a staging app first
python manage.py migrate --plan   # review before applying
```

Watch for: admin login now requires TOTP enrolment (see step 4), and the
Python 3.12 / Django 5.2 upgrade changes the buildpack.

---

## 4. Enrol yourself in admin 2FA immediately after deploy

Admin login now requires TOTP. On first login you are redirected to
`/admin/2fa/setup/`, shown a QR code, and must confirm one code before you can
reach the dashboard. Have an authenticator app ready (Google Authenticator, 1Password, Authy).

**This applies to superusers too.** If you lock yourself out, recover from a shell:

```bash
python manage.py shell -c "
from django_otp.plugins.otp_totp.models import TOTPDevice
TOTPDevice.objects.filter(user__username='admin').delete()
print('device cleared — next login re-runs setup')
"
```

---

## 5. Create the 8 CI secrets

CI now lives at the repo root and runs on push, but needs these in
**GitHub → Settings → Secrets and variables → Actions**:

```bash
# run these locally to produce the values
base64 -i burundi_au_chairmanship/lib/firebase_options.dart | pbcopy            # FIREBASE_OPTIONS_DART_B64
base64 -i burundi_au_chairmanship/android/app/google-services.json | pbcopy     # GOOGLE_SERVICES_JSON_B64
base64 -i burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist | pbcopy  # GOOGLE_SERVICE_INFO_PLIST_B64
base64 -i burundi_au_chairmanship/android/app/upload-keystore.jks | pbcopy      # ANDROID_KEYSTORE_BASE64
```

Plus `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` (from
`android/key.properties`) and `SENTRY_DSN_FLUTTER`.

---

## 6. Verify App Links after deploy

The Play App Signing certificate is now published alongside the upload key, so
Play-signed builds will verify. Confirm once deployed:

```bash
curl -s https://burundi4africa.com/.well-known/assetlinks.json | python3 -m json.tool
```

You should see **two** fingerprints. Then, because Android caches verification
per install:

```bash
adb shell pm verify-app-links --re-verify com.b4africa.app
adb shell pm get-app-links com.b4africa.app     # want: verified
```

---

## 7. Two decisions

**Syncfusion PDF viewer licence.** `syncfusion_flutter_pdfviewer` is commercial
with no licence registered. Community Edition is revenue-gated. For a
government-facing app, get this in writing: https://www.syncfusion.com/sales/teamlicense

**Redis.** You pay ~$15/month for it while `REDIS_URL` may be unset. If it is
unset, `CELERY_TASK_ALWAYS_EAGER` makes every `.delay()` run inline inside the
web request — which is what makes admin bulk sends time out. Either set
`REDIS_URL` in the app spec, or drop the Redis component and accept that
notifications send synchronously.

```bash
doctl apps spec get <app-id> | grep -A2 REDIS_URL   # after: doctl auth init
```

---

## 8. Worth doing, not blocking

- **Run the load tests.** `load_tests/` has k6 scripts that ramp to 40k users and
  have never been run. Start with the smoke variant against staging, not the full
  profile — one uvicorn worker will not survive it.
- **Decide on the 54 root `.md` files.** The blanket `*.md` ignore is gone so they
  are now tracked. Many are stale (superseded audits, old fix notes). I verified
  none contain real credentials, but they are clutter.
- **Data Safety declaration.** The build pulls `AD_ID` and `ACCESS_ADSERVICES_*`
  via Firebase Analytics. Make sure your Play Data Safety form reflects that.
- **Test coverage is thin.** 91 backend tests for a 45-model app. Untested:
  OTP flows, verification badges, support tickets, notification targeting.
