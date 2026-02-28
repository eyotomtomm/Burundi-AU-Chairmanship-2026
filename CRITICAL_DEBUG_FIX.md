# 🚨 CRITICAL SECURITY FIX: DEBUG Defaults to False

**Date**: February 28, 2026
**Severity**: HIGH (Information Disclosure)
**Breaking Change**: YES (Development)

## What Changed

### Before (VULNERABLE ❌)
```python
DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() in ('true', '1', 'yes')
```

**Problem**:
- Defaults to `True` if `DJANGO_DEBUG` env var not set
- If production deployment forgets to set this variable
- Full stack traces exposed to all visitors
- Database queries visible
- Internal file paths revealed
- Settings variables exposed

**Attacks Enabled**:
1. **Information Disclosure**: Full stack traces reveal code structure
2. **Path Disclosure**: Internal file paths leak system information
3. **Database Query Exposure**: SQL queries visible in error pages
4. **Settings Leakage**: Sensitive configuration revealed via debug pages
5. **Attack Surface Mapping**: Attackers learn about dependencies and versions

### After (SECURE ✅)
```python
# Security: DEBUG should default to False (fail-secure)
# Explicitly set DJANGO_DEBUG=True for development
DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')
```

**Fix**:
- Defaults to `False` (fail-secure)
- Development must explicitly set `DJANGO_DEBUG=True`
- Production safe even if env var forgotten
- Forces conscious decision to enable debug mode

## Impact

### Security Impact ✅
- **Stack Traces**: PREVENTED - generic error pages in production
- **SQL Query Exposure**: PREVENTED - queries hidden from visitors
- **Path Disclosure**: PREVENTED - no internal paths revealed
- **Settings Leakage**: PREVENTED - no debug pages
- **Attack Surface Mapping**: PREVENTED - minimal information disclosure

### Development Impact ⚠️
- **Breaking Change**: YES - must explicitly set `DJANGO_DEBUG=True`
- **Error Messages**: Less verbose (need to check logs)
- **Static Files**: Must run collectstatic or use --insecure flag
- **Setup Required**: One-time environment variable addition

## Information Disclosure Examples

### Stack Traces in Production (Before Fix)

When DEBUG=True and an error occurs, Django shows:
```
Exception Type: AttributeError
Exception Value: 'NoneType' object has no attribute 'email'
Exception Location: /app/core/views.py, line 127

Traceback (most recent call last):
  File "/app/core/views.py", line 127, in user_profile
    email = user.email
            ^^^^^^^^^^^
AttributeError: 'NoneType' object has no attribute 'email'

Settings:
  SECRET_KEY = 'django-insecure-...'  # Exposed!
  DATABASES = {...}                   # Connection info exposed!
  MIDDLEWARE = [...]                  # Internal structure exposed!
```

**Attackers Learn**:
- Code structure and file paths
- Django version
- Middleware stack
- Installed packages
- Database type
- Configuration details

### After Fix

With DEBUG=False:
```
Server Error (500)
```

Clean, minimal error page. No information leaked.

## Attack Scenarios Prevented

### Scenario 1: Code Structure Discovery
**Before**:
1. Attacker triggers errors to get stack traces
2. Learns file structure: `/app/core/views.py`, `/app/auth/models.py`
3. Discovers dependencies and versions
4. Identifies known vulnerabilities in dependencies
5. Plans targeted attack

**After**: ✅ PREVENTED
- Generic 500 error page
- No code structure revealed
- Errors logged server-side only

### Scenario 2: SQL Injection Discovery
**Before**:
1. With DEBUG=True, all SQL queries shown in debug toolbar
2. Attacker sees: `SELECT * FROM users WHERE id = 1`
3. Discovers table structure and column names
4. Crafts targeted SQL injection attacks

**After**: ✅ PREVENTED
- No SQL queries visible to users
- Database schema remains hidden

### Scenario 3: Path Traversal Reconnaissance
**Before**:
1. Error pages reveal: `/Users/admin/app/django/...`
2. Attacker learns server OS (macOS/Linux/Windows)
3. Learns user account names
4. Learns deployment structure
5. Plans path traversal attacks

**After**: ✅ PREVENTED
- No file paths exposed
- System information hidden

## Configuration Matrix

| Environment | DEBUG | Result | Stack Traces | Static Files |
|-------------|-------|--------|-------------|--------------|
| **Development (Before)** | True (default) | Works | ✅ Shown | ✅ Auto-served |
| **Development (After)** | Must set True | Works | ✅ Shown | ✅ Auto-served |
| **Production (Before)** | True (if forgot) | ❌ Info leak | ⚠️ Exposed | Works |
| **Production (After)** | False (default) | ✅ Secure | ❌ Hidden | Needs collectstatic |

## Setup Instructions

### Development (New Requirement)
```bash
# Must explicitly enable DEBUG for development
export DJANGO_SECRET_KEY='your-dev-key'
export DJANGO_DEBUG=True  # NEW: Required for development

python manage.py runserver
```

Or create `.env.local`:
```bash
DJANGO_SECRET_KEY=your-dev-key
DJANGO_DEBUG=True
```

### Production (No Change)
```bash
# DEBUG defaults to False, no need to set
export DJANGO_SECRET_KEY='your-prod-key'
export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com'
# DJANGO_DEBUG=False  # Optional, already the default

python manage.py runserver
```

### Static Files in Production
```bash
# Collect static files when DEBUG=False
python manage.py collectstatic --noinput
```

## Verification Tests

### Test 1: Development Requires DEBUG=True
```bash
export DJANGO_SECRET_KEY='test'
unset DJANGO_DEBUG  # Don't set DEBUG
python manage.py runserver

# Expected:
# - Server runs but with DEBUG=False
# - Static files won't be served
# - Need to run with --insecure or set DEBUG=True
```

### Test 2: Production Defaults to Secure
```bash
export DJANGO_SECRET_KEY='test'
export DJANGO_ALLOWED_HOSTS='example.com'
unset DJANGO_DEBUG  # Forgot to set it
python manage.py check

# Expected:
# - DEBUG=False (secure default)
# - No stack traces will be shown
# - Production-ready ✅
```

### Test 3: Stack Traces Only When Explicitly Enabled
```bash
# Create an error endpoint
curl http://localhost:8000/api/error-test/

# With DEBUG=False (default):
# Response: "Server Error (500)" - minimal page

# With DEBUG=True (explicit):
# Response: Full stack trace with code and paths
```

## Migration for Developers

### Before
```bash
# Just worked without any environment setup
python manage.py runserver
```

### After
```bash
# Must set DEBUG=True for development
export DJANGO_DEBUG=True
python manage.py runserver

# OR add to .env.local:
echo "DJANGO_DEBUG=True" >> .env.local
export $(cat .env.local | xargs)
python manage.py runserver

# OR run with --settings flag
python manage.py runserver --settings=config.settings_dev
```

## Static Files Handling

### Development with DEBUG=False
If you need to test with DEBUG=False locally:

```bash
# Option 1: Collect static files
python manage.py collectstatic

# Option 2: Use --insecure flag (not recommended)
python manage.py runserver --insecure
```

### Production
Always collect static files:
```bash
python manage.py collectstatic --noinput
```

Configure WhiteNoise (already configured):
```python
MIDDLEWARE = [
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Serves static files
    ...
]
```

## Error Handling

### With DEBUG=False (Production)
Custom error pages shown:
- `400.html` - Bad Request
- `403.html` - Forbidden
- `404.html` - Not Found
- `500.html` - Server Error

Create these templates in `templates/` directory for branded error pages.

### Logging Errors
Errors are logged to console/file even with DEBUG=False:

```python
# settings.py - already configured
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': 'django_errors.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': True,
        },
    },
}
```

## Security Best Practices

### ✅ DO
- Always default to DEBUG=False
- Explicitly enable DEBUG=True in development
- Never run production with DEBUG=True
- Use error monitoring (Sentry, Rollbar)
- Create custom error templates
- Log errors to files/services

### ❌ DON'T
- Default DEBUG to True
- Run production with DEBUG=True
- Expose stack traces to users
- Rely on DEBUG pages for error investigation
- Forget to collect static files in production

## Complete Security Configuration

All four critical settings now fail-secure:

```python
# 1. SECRET_KEY - No fallback
try:
    SECRET_KEY = os.environ['DJANGO_SECRET_KEY']
except KeyError:
    raise RuntimeError("CRITICAL: DJANGO_SECRET_KEY not set")

# 2. DEBUG - Defaults to False
DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')

# 3. ALLOWED_HOSTS - No wildcard default
if DEBUG:
    ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]']
else:
    if not os.environ.get('DJANGO_ALLOWED_HOSTS'):
        raise RuntimeError("CRITICAL: DJANGO_ALLOWED_HOSTS not set")
    ALLOWED_HOSTS = os.environ['DJANGO_ALLOWED_HOSTS'].split(',')
```

All four settings now require explicit configuration in production and fail safely if misconfigured.

## Files Modified

1. **`backend/config/settings.py`**:
   - Changed DEBUG default from 'True' to 'False'
   - Added security comment

2. **`backend/.env.local.example`**:
   - Added comment emphasizing DEBUG=True requirement

## Quick Reference

### Development Setup
```bash
export DJANGO_SECRET_KEY='dev-key'
export DJANGO_DEBUG=True  # Required!
python manage.py runserver
```

### Production Setup
```bash
export DJANGO_SECRET_KEY='prod-key'
export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com'
# DEBUG defaults to False - secure!
python manage.py collectstatic --noinput
python manage.py runserver
```

### Check Current DEBUG Value
```bash
python -c "from django.conf import settings; print(f'DEBUG={settings.DEBUG}')"
```

---

**This completes the security quadruple: SECRET_KEY, ALLOWED_HOSTS, DEBUG, and frontend HTTPS enforcement.**

**Status**: ✅ Fixed
**Severity**: High → Resolved
**Breaking**: Yes (development must set DEBUG=True)
**Production Impact**: Positive (more secure by default)
