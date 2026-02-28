# 🚨 CRITICAL SECURITY FIX: ALLOWED_HOSTS Wildcard Removed

**Date**: February 28, 2026
**Severity**: CRITICAL
**Breaking Change**: YES (Production only)

## What Changed

### Before (VULNERABLE ❌)
```python
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')
```

**Problem**:
- Default `'*'` accepts requests from ANY host
- If `DJANGO_ALLOWED_HOSTS` env var not set (common in hasty deployments)
- Django accepts all Host headers

**Attacks Enabled**:
1. **HTTP Host Header Attacks**: Attackers can manipulate password reset links
2. **Cache Poisoning**: Can poison web cache with malicious hosts
3. **URL Hijacking**: Password reset URLs sent to attacker's domain
4. **Email Spoofing**: Password reset emails with attacker's domain

### After (SECURE ✅)
```python
# Security: ALLOWED_HOSTS must be explicitly set
allowed_hosts_env = os.environ.get('DJANGO_ALLOWED_HOSTS', '')
if allowed_hosts_env:
    ALLOWED_HOSTS = [host.strip() for host in allowed_hosts_env.split(',') if host.strip()]
elif DEBUG:
    # Only allow localhost in development
    ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]']
else:
    # Production MUST have explicit ALLOWED_HOSTS
    raise RuntimeError(
        "CRITICAL: DJANGO_ALLOWED_HOSTS environment variable is not set.\n"
        "This is required in production to prevent HTTP Host header attacks.\n\n"
        "Set it to your domain(s):\n"
        "  export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com'\n"
    )
```

**Fix**:
- NO wildcard default
- Development: Auto-defaults to localhost only
- Production: MUST explicitly set domains or crash
- Forces security configuration

## Impact

### Security Impact ✅
- **Host Header Attacks**: PREVENTED - only listed domains accepted
- **Cache Poisoning**: PREVENTED - cache only serves whitelisted hosts
- **Password Reset Hijacking**: PREVENTED - reset URLs only use valid domains
- **Email Spoofing**: PREVENTED - emails only reference allowed hosts

### Development Impact
- **DEBUG=True**: No change needed (auto-allows localhost)
- **Local Testing**: Works without configuration
- **Breaking**: None for development

### Production Impact ⚠️
- **Breaking Change**: YES - must set `DJANGO_ALLOWED_HOSTS`
- **Without Env Var**: Application crashes (intentional)
- **With Env Var**: Works normally

## Attack Scenarios Prevented

### 1. Password Reset Hijacking
**Before (Vulnerable)**:
```http
POST /api/auth/password-reset/
Host: attacker.com

email=victim@example.com
```

Django would:
- Accept the request
- Generate password reset link: `http://attacker.com/reset/token123`
- Send email to victim with attacker's domain
- Victim clicks link → token goes to attacker

**After (Secure)**:
- Request rejected with 400 Bad Request
- Only requests with allowed Host headers accepted

### 2. Cache Poisoning
**Before (Vulnerable)**:
```http
GET /api/articles/
Host: attacker.com
```

Web cache stores response as:
```
Cache-Key: attacker.com/api/articles/
```

Future users requesting legitimate domain get attacker's cached response.

**After (Secure)**:
- Request rejected
- Cache only stores responses for whitelisted domains

### 3. Email Link Manipulation
Password reset, account verification, and notification emails all use the Host header to construct links. With `ALLOWED_HOSTS = '*'`, attackers control these URLs.

## Setup Instructions

### Production Deployment
```bash
# Set your production domain(s)
export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com,www.burundi4africa.com'
export DJANGO_DEBUG=False
```

**DigitalOcean App Platform**:
```
Settings → Environment Variables → Add:
  DJANGO_ALLOWED_HOSTS = api.burundi4africa.com,burundi4africa.com
  DJANGO_DEBUG = False
```

**Heroku**:
```bash
heroku config:set DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com'
heroku config:set DJANGO_DEBUG=False
```

**Docker**:
```yaml
# docker-compose.yml
environment:
  - DJANGO_ALLOWED_HOSTS=api.burundi4africa.com,burundi4africa.com
  - DJANGO_DEBUG=False
```

### Development (No Change Needed)
```bash
# Just set SECRET_KEY, ALLOWED_HOSTS auto-defaults to localhost
export DJANGO_SECRET_KEY='your-dev-key'
export DJANGO_DEBUG=True
python manage.py runserver
```

ALLOWED_HOSTS automatically set to:
```python
['localhost', '127.0.0.1', '[::1]']
```

### Staging
```bash
export DJANGO_ALLOWED_HOSTS='staging-api.burundi4africa.com'
export DJANGO_DEBUG=False
```

## Verification

### Test Production Configuration
```bash
# Should fail without ALLOWED_HOSTS
export DJANGO_SECRET_KEY='test-key'
export DJANGO_DEBUG=False
unset DJANGO_ALLOWED_HOSTS
python manage.py check

# Expected: RuntimeError about missing DJANGO_ALLOWED_HOSTS ✅
```

```bash
# Should succeed with ALLOWED_HOSTS
export DJANGO_SECRET_KEY='test-key'
export DJANGO_DEBUG=False
export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com'
python manage.py check

# Expected: System check identified no issues ✅
```

### Test Development Configuration
```bash
# Should succeed without ALLOWED_HOSTS (defaults to localhost)
export DJANGO_SECRET_KEY='test-key'
export DJANGO_DEBUG=True
unset DJANGO_ALLOWED_HOSTS
python manage.py check

# Expected: System check identified no issues ✅
# ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]']
```

## Error Messages

### Production Without ALLOWED_HOSTS
```
RuntimeError: CRITICAL: DJANGO_ALLOWED_HOSTS environment variable is not set.
This is required in production to prevent HTTP Host header attacks.

Set it to your domain(s):
  export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com'

Multiple hosts should be comma-separated.
```

This is **intentional** and **correct**.

## Security Best Practices

### ✅ DO
- List only your actual domains
- Include all variants (www, api, etc.)
- Use specific domains, never wildcards
- Keep list minimal
- Update when adding new domains

### ❌ DON'T
- Use `'*'` wildcard
- Add unnecessary domains
- Use IP addresses unless necessary
- Include http:// or https:// (just domain)
- Add subdomains you don't control

### Example Configurations

**Single Domain**:
```bash
DJANGO_ALLOWED_HOSTS='api.burundi4africa.com'
```

**Multiple Domains**:
```bash
DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com,www.burundi4africa.com'
```

**With Subdomains**:
```bash
# BAD - Too permissive
DJANGO_ALLOWED_HOSTS='*.burundi4africa.com'

# GOOD - Explicit list
DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,admin.burundi4africa.com,burundi4africa.com'
```

## Files Modified

1. **`backend/config/settings.py`**:
   - Removed wildcard default
   - Added DEBUG check for development
   - Added production validation

2. **`backend/.env.example`**:
   - Updated ALLOWED_HOSTS example

3. **`backend/.env.local.example`**:
   - Clarified ALLOWED_HOSTS not needed in dev

## Combined Security Fixes

This fix completes the trinity of critical Django security settings:

| Setting | Before | After |
|---------|--------|-------|
| `SECRET_KEY` | Fallback in git | No fallback, crash if missing |
| `ALLOWED_HOSTS` | `'*'` default | No default, crash if missing in prod |
| `DEBUG` | Defaults to `True` | Must explicitly set to `False` in prod |

All three now enforce explicit security configuration in production.

## Migration Checklist

- [x] Remove wildcard default from settings.py
- [x] Add DEBUG-aware logic
- [x] Add production validation
- [x] Update .env.example
- [x] Update .env.local.example
- [x] Create documentation (this file)
- [ ] Notify DevOps team
- [ ] Update deployment scripts
- [ ] Set ALLOWED_HOSTS in all environments
- [ ] Test production deployment
- [ ] Verify password reset emails work correctly

## Testing Checklist

### Before Deployment
- [ ] Test with valid ALLOWED_HOSTS
- [ ] Test without ALLOWED_HOSTS (should crash in prod)
- [ ] Test password reset flow
- [ ] Verify email links use correct domain
- [ ] Test with incorrect Host header (should reject)
- [ ] Check cache behavior
- [ ] Run security scan

### After Deployment
- [ ] Verify API accepts requests with correct Host
- [ ] Verify API rejects requests with incorrect Host
- [ ] Test password reset email links
- [ ] Check all email notifications
- [ ] Monitor for 400 errors (incorrect Host headers)

## Rollback Plan

If issues arise:

```bash
# Temporary rollback (INSECURE - only for emergency)
export DJANGO_ALLOWED_HOSTS='*'

# Better: Add the correct domain
export DJANGO_ALLOWED_HOSTS='your-actual-domain.com'
```

## FAQ

### Q: Why crash instead of defaulting to localhost?
**A**: In production, accepting only localhost would break the app. Better to crash and force explicit configuration than silently fail.

### Q: What if I have multiple domains?
**A**: List them all, comma-separated: `'domain1.com,domain2.com,www.domain1.com'`

### Q: Does this affect mobile apps?
**A**: No. Mobile apps don't send Host headers. This only affects web requests and password reset emails.

### Q: What about load balancers?
**A**: Add your load balancer's domain or all domains it serves. Don't add the load balancer's IP.

### Q: Can I use wildcards for subdomains?
**A**: Django doesn't support wildcard ALLOWED_HOSTS well. List each subdomain explicitly for security.

---

**This is a critical security improvement. The breaking change is intentional and necessary.**

**Status**: ✅ Fixed
**Severity**: Critical → Resolved
**Breaking**: Yes (production only)
**Documentation**: Complete
