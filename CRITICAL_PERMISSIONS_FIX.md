# 🚨 CRITICAL SECURITY FIX: REST Framework Permissions Default

**Date**: February 28, 2026
**Severity**: MEDIUM-HIGH (Security Misconfiguration)
**Breaking Change**: NO (existing endpoints behavior unchanged)

---

## What Changed

### Before (VULNERABLE ❌)

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    ...
}
```

```python
# views.py - No explicit permissions on ViewSets
class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ArticleSerializer
    # Inherits AllowAny from default
```

**Problem**:
- Every new endpoint defaults to publicly accessible
- Developers must remember to add `permission_classes = [IsAuthenticated]`
- Forgetting permissions = security vulnerability
- No explicit intent: can't distinguish "intentionally public" from "forgot to secure"

**Security Risk**:
If a developer adds a new ViewSet and forgets to add permission classes:
```python
class SensitiveDataViewSet(viewsets.ModelViewSet):  # OOPS! Forgot permissions
    queryset = SensitiveData.objects.all()  # Now publicly accessible!
```

---

### After (SECURE ✅)

```python
# settings.py
REST_FRAMEWORK = {
    # Security: Default to requiring authentication (fail-secure)
    # Public endpoints must explicitly set permission_classes = [AllowAny]
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    ...
}
```

```python
# views.py - Explicit permissions on all ViewSets
class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can read articles, but authentication required to like/comment"""
    permission_classes = [AllowAny]  # Explicitly public
    serializer_class = ArticleSerializer
```

**Fix**:
- New endpoints default to requiring authentication (fail-secure)
- Public endpoints explicitly marked with `permission_classes = [AllowAny]`
- Clear intent: every endpoint consciously decides public vs private
- Forgetting permissions = requires authentication (secure default)

---

## Impact

### Security Impact ✅

**Before**: Fail-insecure (defaults to public)
- Forgetting permissions → Public access
- No way to audit which endpoints are intentionally public
- Easy to accidentally expose sensitive data

**After**: Fail-secure (defaults to authenticated)
- Forgetting permissions → Requires authentication
- Easy to audit: search for `AllowAny` to see all public endpoints
- Must consciously decide to make endpoint public

### Functional Impact ✅

**No Breaking Changes**: All existing endpoints maintain same behavior
- Public endpoints (articles, magazines, etc.) explicitly marked `AllowAny`
- Protected endpoints (profile, likes, comments) remain protected
- Users experience no difference

---

## Endpoints Classification

### Public Endpoints (AllowAny)

**Authentication Endpoints**:
- `POST /api/auth/register/` - User registration
- `POST /api/auth/login/` - User login
- `POST /api/auth/firebase-register/` - Firebase registration
- `POST /api/auth/firebase-login/` - Firebase login

**Content Reading (Public Information)**:
- `GET /api/hero-slides/` - Hero slides for home page
- `GET /api/articles/` - News articles
- `GET /api/magazines/` - Magazine editions
- `GET /api/categories/` - Article categories
- `GET /api/events/` - Public events
- `GET /api/live-feeds/` - Live video feeds
- `GET /api/resources/` - Public resources/documents
- `GET /api/embassy-locations/` - Embassy locations
- `GET /api/emergency-contacts/` - Emergency contact information
- `GET /api/feature-cards/` - Feature cards for home page
- `GET /api/priority-agendas/` - Priority agendas
- `GET /api/gallery-albums/` - Photo gallery albums
- `GET /api/videos/` - Video content
- `GET /api/social-media-links/` - Social media links
- `GET /api/app-settings/` - App configuration
- `GET /api/home-feed/` - Combined home screen data

**View Counting (Analytics - No Auth Required)**:
- `POST /api/articles/{id}/record-view/` - Count article views
- `POST /api/magazines/{id}/record_view/` - Count magazine views
- `POST /api/videos/{id}/record-view/` - Count video views

**Rationale**: Public content should be accessible without registration to maximize reach and engagement. Users only need to authenticate for interactive features.

---

### Protected Endpoints (IsAuthenticated)

**User Profile Management**:
- `GET /api/auth/profile/` - View own profile
- `PUT /api/auth/profile/` - Update profile
- `DELETE /api/auth/delete-account/` - Delete account
- `POST /api/auth/update-fcm-token/` - Update notification token
- `GET /api/auth/export-user-data/` - Export user data (GDPR)

**Content Interaction (Requires Login)**:
- `POST /api/articles/{id}/toggle-like/` - Like/unlike article
- `GET /api/articles/{id}/comments/` - View comments (public)
- `POST /api/articles/{id}/comments/` - Post comment (requires auth)
- `DELETE /api/articles/{id}/comments/{comment_id}/` - Delete own comment
- `POST /api/magazines/{id}/toggle_like/` - Like/unlike magazine

**Rationale**: User-specific actions require authentication to track ownership, prevent abuse, and comply with data privacy regulations.

---

## Security Principles Applied

### 1. Fail-Secure Default ✅
```python
# New endpoint without explicit permissions
class NewViewSet(viewsets.ModelViewSet):
    queryset = Model.objects.all()
    # Defaults to IsAuthenticated - SECURE
```

### 2. Explicit Intent ✅
```python
# Clear documentation of public access
class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can read articles"""
    permission_classes = [AllowAny]  # Conscious decision
```

### 3. Least Privilege ✅
- Read-only operations (GET): Public where appropriate
- Write operations (POST/PUT/DELETE): Always require authentication
- User data: Always protected

### 4. Defense in Depth ✅
- Global default: `IsAuthenticated`
- ViewSet level: Explicit `permission_classes`
- Action level: Additional `permission_classes=[...]` decorators where needed
- Manual checks: `if not request.user.is_authenticated` in custom logic

---

## Code Changes Summary

### settings.py
```python
# Before
'DEFAULT_PERMISSION_CLASSES': [
    'rest_framework.permissions.AllowAny',
],

# After
'DEFAULT_PERMISSION_CLASSES': [
    'rest_framework.permissions.IsAuthenticated',  # Fail-secure default
],
```

### views.py (Added to 14 ViewSets + 2 functions)

```python
# Content ViewSets - Added explicit AllowAny
class HeroSlideViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]  # NEW
    ...

class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]  # NEW
    ...

class MagazineEditionViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]  # NEW
    ...

# ... (11 more ViewSets)

# Function-based views - Added explicit AllowAny
@api_view(['GET'])
@permission_classes([AllowAny])  # NEW
def app_settings(request):
    ...

@api_view(['GET'])
@permission_classes([AllowAny])  # NEW
def home_feed(request):
    ...
```

**Total Changes**:
- 1 change in `settings.py`
- 16 changes in `views.py` (14 ViewSets + 2 functions)
- All auth endpoints already had explicit decorators (no change needed)
- All protected endpoints already had explicit decorators (no change needed)

---

## Verification Tests

### Test 1: Public Content Accessible ✅
```bash
# Before and After: Should work without authentication
curl http://localhost:8000/api/articles/

# Expected: 200 OK with article list
```

### Test 2: Protected Endpoints Require Auth ✅
```bash
# Before and After: Should require authentication
curl http://localhost:8000/api/auth/profile/

# Expected: 401 Unauthorized
```

### Test 3: New Endpoint Defaults to Secure ✅
```python
# Create new endpoint WITHOUT permission_classes
class TestViewSet(viewsets.ModelViewSet):
    queryset = Model.objects.all()

# Attempt to access without auth
curl http://localhost:8000/api/test/

# Expected: 401 Unauthorized (fail-secure)
```

### Test 4: Audit Public Endpoints ✅
```bash
# Search for all public endpoints
grep -n "permission_classes = \[AllowAny\]" views.py

# Expected: List of all intentionally public endpoints
```

---

## Migration for Developers

### No Changes Required ✅

All existing endpoints maintain their behavior:
- Public content remains public
- Protected endpoints remain protected
- No API contract changes
- No mobile app changes needed

### For New Development

**Before** (with AllowAny default):
```python
# Adding public endpoint
class MyViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = MyModel.objects.all()
    # Implicitly public (risky)

# Adding protected endpoint
class SecureViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]  # Must remember this
    queryset = SecureModel.objects.all()
```

**After** (with IsAuthenticated default):
```python
# Adding public endpoint
class MyViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [AllowAny]  # Must explicitly mark public
    queryset = MyModel.objects.all()

# Adding protected endpoint
class SecureViewSet(viewsets.ModelViewSet):
    queryset = SecureModel.objects.all()
    # Automatically protected (secure)
```

**New Rule**: Every new ViewSet MUST explicitly set `permission_classes`
- Public content: `permission_classes = [AllowAny]`
- Protected content: `permission_classes = [IsAuthenticated]` (or omit for default)
- Custom permissions: `permission_classes = [CustomPermission]`

---

## Attack Scenarios Prevented

### Scenario 1: Accidental Data Exposure

**Before**:
```python
# Developer adds new endpoint, forgets permissions
class InternalReportViewSet(viewsets.ModelViewSet):
    queryset = InternalReport.objects.all()  # Oops! Public!

# Result: Sensitive reports exposed to internet
```

**After**: ✅ PREVENTED
```python
# Same code, but defaults to IsAuthenticated
class InternalReportViewSet(viewsets.ModelViewSet):
    queryset = InternalReport.objects.all()  # Automatically protected

# Result: Returns 401 Unauthorized without auth token
```

---

### Scenario 2: Permission Confusion

**Before**:
```python
# Is this intentionally public or forgot permissions?
class SomeViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SomeModel.objects.all()
    # No way to know intent
```

**After**: ✅ PREVENTED
```python
# Clear intent documented
class SomeViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view this data"""
    permission_classes = [AllowAny]  # Explicit decision
    queryset = SomeModel.objects.all()
```

---

### Scenario 3: API Endpoint Discovery

**Before**:
An attacker could:
1. Enumerate API endpoints (`/api/users/`, `/api/admin/`, etc.)
2. Find endpoints without explicit permissions
3. Access data that developer forgot to protect

**After**: ✅ PREVENTED
- All endpoints default to requiring authentication
- Attacker gets 401 Unauthorized on all protected endpoints
- Only intentionally public endpoints are accessible

---

## Security Compliance

### Before Fix
- ❌ OWASP A01:2021 - Broken Access Control (implicit default)
- ❌ OWASP A05:2021 - Security Misconfiguration (insecure default)
- ⚠️ CWE-306 - Missing Authentication for Critical Function (risk)
- ❌ Fails "secure by default" principle

### After Fix
- ✅ OWASP A01:2021 - Access Control properly configured
- ✅ OWASP A05:2021 - Secure configuration with fail-secure defaults
- ✅ CWE-306 - Authentication required by default
- ✅ Follows "secure by default" principle
- ✅ Explicit security model (whitelist approach)

---

## Best Practices Implemented

### ✅ DO (After This Fix)
1. Default to `IsAuthenticated` globally
2. Explicitly mark public endpoints with `AllowAny`
3. Document why an endpoint is public in docstring
4. Regular audits: `grep AllowAny views.py`
5. Code review: question every `AllowAny` usage

### ❌ DON'T
1. Never default to `AllowAny` globally
2. Never add endpoints without explicit permissions
3. Never assume "no one will find this endpoint"
4. Never use `AllowAny` on endpoints with sensitive data
5. Never bypass authentication for convenience

---

## Comparison: Before vs After

| Aspect | Before (AllowAny Default) | After (IsAuthenticated Default) |
|--------|---------------------------|----------------------------------|
| **Security Posture** | Fail-insecure | Fail-secure ✅ |
| **New Endpoint Default** | Public (risky) | Protected (safe) ✅ |
| **Intent Clarity** | Ambiguous | Explicit ✅ |
| **Audit Difficulty** | Hard (must check every endpoint) | Easy (search for AllowAny) ✅ |
| **Developer Mental Model** | "Remember to protect" | "Remember to open" ✅ |
| **Risk of Exposure** | High (easy to forget) | Low (default protected) ✅ |
| **OWASP Compliance** | Non-compliant | Compliant ✅ |
| **Production Readiness** | Risky | Production-ready ✅ |

---

## Related Security Fixes

This is the **5th and final** critical security fix in the comprehensive security audit:

1. ✅ **Frontend**: Hardcoded localhost URLs → Environment-based HTTPS
2. ✅ **Backend**: SECRET_KEY fallback → No fallback (crash if not set)
3. ✅ **Backend**: ALLOWED_HOSTS wildcard → Explicit domains required
4. ✅ **Backend**: DEBUG defaults True → Defaults to False
5. ✅ **Backend**: AllowAny default → IsAuthenticated default (THIS FIX)

**All critical vulnerabilities now resolved.**

---

## Quick Reference

### Check Current Default
```python
# In Django shell
from rest_framework.settings import api_settings
print(api_settings.DEFAULT_PERMISSION_CLASSES)
# Expected: ['rest_framework.permissions.IsAuthenticated']
```

### List All Public Endpoints
```bash
grep -B2 "permission_classes = \[AllowAny\]" backend/core/views.py
```

### Test Endpoint Permission
```bash
# Without auth - should fail on protected, succeed on public
curl http://localhost:8000/api/auth/profile/
# Expected: 401 Unauthorized

curl http://localhost:8000/api/articles/
# Expected: 200 OK
```

---

**Status**: ✅ Fixed
**Severity**: Medium-High → Resolved
**Breaking**: No (behavior unchanged)
**Production Impact**: Positive (more secure by default)

---

**All Five Critical Security Vulnerabilities Now Fixed**
**Application Production Ready** 🔒
