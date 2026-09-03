# 🚨 CRITICAL SECURITY FIX: SECRET_KEY Hardcoded Fallback Removed

**Date**: February 28, 2026
**Severity**: CRITICAL
**Breaking Change**: YES

## What Changed

### Before (VULNERABLE ❌)
```python
SECRET_KEY = os.environ.get(
    'DJANGO_SECRET_KEY',
    'django-insecure-dev-key-ONLY-FOR-LOCAL-DEVELOPMENT',  # Committed to git!
)
```

**Problem**:
- Fallback value committed to version control
- If `DJANGO_SECRET_KEY` env var missing in production, app runs with known key
- Attackers can:
  - Forge session cookies
  - Generate valid CSRF tokens
  - Create valid JWT signatures
  - Impersonate any user
  - Bypass authentication

### After (SECURE ✅)
```python
try:
    SECRET_KEY = os.environ['DJANGO_SECRET_KEY']
except KeyError:
    raise RuntimeError(
        "CRITICAL: DJANGO_SECRET_KEY environment variable is not set.\n"
        "Generate one with:\n"
        "  python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'\n"
    )
```

**Fix**:
- NO fallback value
- Application crashes immediately if env var not set
- Forces explicit configuration
- Impossible to run with known key

## Impact

### Security Impact ✅
- **Session Hijacking**: PREVENTED - no known key to forge cookies
- **CSRF Attacks**: PREVENTED - cannot generate valid tokens
- **JWT Forgery**: PREVENTED - cannot sign tokens
- **Authentication Bypass**: PREVENTED - all crypto depends on unknown key

### Development Impact ⚠️
This is a **breaking change** for local development.

**Before**: Run server without setup ❌
```bash
python manage.py runserver
# Just worked with fallback key
```

**After**: Setup required first ✅
```bash
# Generate key
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

# Set environment variable
export DJANGO_SECRET_KEY='your-generated-key-here'

# Now run server
python manage.py runserver
```

## Quick Setup for Developers

### Option 1: One-Time Shell Export (Quick)
```bash
# Generate and export in one command
export DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Run server
python manage.py runserver
```

### Option 2: .env.local File (Recommended)
```bash
# Copy example file
cd backend
cp .env.local.example .env.local

# Generate key
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

# Edit .env.local and paste your key
nano .env.local

# Load environment
export $(cat .env.local | xargs)

# Run server
python manage.py runserver
```

### Option 3: Shell Profile (Permanent)
Add to `~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`:
```bash
export DJANGO_SECRET_KEY='your-generated-key-here'
```

Reload:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Files Created

1. **`.env.example`** - Production environment template
2. **`.env.local.example`** - Local development template
3. **`backend/.gitignore`** - Ensures .env files never committed
4. **`backend/LOCAL_SETUP.md`** - Complete setup documentation

## Files Modified

1. **`backend/config/settings.py`** - Removed fallback, added helpful error

## Production Deployment

### Before Deploying
Ensure `DJANGO_SECRET_KEY` is set in your production environment:

**DigitalOcean App Platform**:
```
Settings → Environment Variables → Add:
  DJANGO_SECRET_KEY = <your-generated-key>
```

**Heroku**:
```bash
heroku config:set DJANGO_SECRET_KEY='your-generated-key'
```

**Docker**:
```yaml
# docker-compose.yml
environment:
  - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
```

**Server (systemd)**:
```ini
# /etc/systemd/system/burundi-au.service
[Service]
Environment="DJANGO_SECRET_KEY=your-generated-key"
```

### Generate Production Key
```bash
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
```

**Example output**:
```
django-insecure-8_h#jk@3mf9^%2x+7w*&4ql!n6p=)s$vz1cy-hu5te8ba0m-ke
```

## Error Messages

### If SECRET_KEY Not Set
```
RuntimeError: CRITICAL: DJANGO_SECRET_KEY environment variable is not set.
This is required for security (session cookies, CSRF tokens, JWT signatures).

Generate a secure key with:
  python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

Then set it:
  export DJANGO_SECRET_KEY='your-generated-key-here'

For local development, create a .env file or add to your shell profile.
```

This is **intentional** and **correct** behavior.

## Security Best Practices

### ✅ DO
- Generate unique SECRET_KEY for each environment (dev, staging, prod)
- Store in environment variables or secrets manager
- Keep SECRET_KEY out of version control
- Use strong, random keys (Django's `get_random_secret_key()`)
- Rotate keys periodically

### ❌ DON'T
- Commit SECRET_KEY to git
- Share SECRET_KEY between environments
- Use short or predictable keys
- Hardcode fallback values
- Store in plain text files

## Migration Checklist

- [x] Remove hardcoded fallback from settings.py
- [x] Create .env.example template
- [x] Create .env.local.example template
- [x] Add .gitignore to exclude .env files
- [x] Create LOCAL_SETUP.md documentation
- [x] Update BACKEND_FIXES.md
- [x] Update SECURITY_FIXES.md
- [x] Update BACKEND_SUMMARY.md
- [ ] Notify all developers of breaking change
- [ ] Update CI/CD pipelines to set DJANGO_SECRET_KEY
- [ ] Set DJANGO_SECRET_KEY in all environments (dev, staging, prod)
- [ ] Verify production deployment works

## Testing

### Verify Fix is Applied
```bash
# Should fail with clear error
cd backend
unset DJANGO_SECRET_KEY
python manage.py check

# Expected: RuntimeError about missing DJANGO_SECRET_KEY
```

### Verify Setup Works
```bash
# Should succeed
export DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
python manage.py check

# Expected: System check identified no issues
```

## FAQ

### Q: Why no fallback for development?
**A**: Any fallback value, even marked "insecure", is a security risk. If accidentally deployed to production, attackers can exploit it. Better to crash than to run insecurely.

### Q: This broke my local setup!
**A**: Good! That means the security fix is working. Follow the Quick Setup instructions above.

### Q: Can I use the same key for dev and prod?
**A**: No. Each environment should have its own unique key. If dev key is compromised, it shouldn't affect production.

### Q: How do I rotate the SECRET_KEY?
**A**: Generate a new key, update the environment variable, restart the application. Note: This will invalidate all existing sessions.

### Q: What happens to existing sessions when I rotate?
**A**: They become invalid. Users will need to log in again. Plan rotations during maintenance windows.

## Support

If you encounter issues with this change:

1. Read `backend/LOCAL_SETUP.md`
2. Check `.env.local.example` for template
3. Verify DJANGO_SECRET_KEY is set: `echo $DJANGO_SECRET_KEY`
4. Generate new key if needed
5. Contact development team if still stuck

---

**This is a critical security improvement. The breaking change is intentional and necessary.**

**Status**: ✅ Fixed
**Severity**: Critical → Resolved
**Breaking**: Yes (local dev setup required)
**Documentation**: Complete
