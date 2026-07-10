"""Section-level permissions for the custom admin portal.

Usage model
-----------
Every custom_admin URL is mapped to one "section" (a coarse-grained feature
group like 'content', 'events', 'emails'). A staff user can access a URL only
if their `UserProfile.admin_sections` list contains the section key.

Superusers bypass all checks. Authenticated non-staff users cannot reach the
admin at all (separate auth gate).

The list of sections is the single source of truth for both:
  1. The "Edit Access" checklist in the admin management page
  2. The sidebar filter (context processor in context_processors.py)
  3. The middleware that blocks direct URL access (below)
"""
from django.http import HttpResponseForbidden
from django.template.loader import render_to_string
from django.urls import resolve, Resolver404


# ═══════════════════════════════════════════════════════════════
# Menu catalog — one entry per sidebar menu item
# ═══════════════════════════════════════════════════════════════
# Grouped for display in the Edit Access modal. Each leaf tuple:
#   (menu_key, label, material-icon)
# The menu_key equals the URL name of the main list/landing page for
# that menu. URL-name prefix matching (see get_required_menu below)
# automatically grants CRUD variants like `article_create`, `article_edit`.
ADMIN_MENU_GROUPS = [
    ('Dashboard & Analytics', [
        ('dashboard',                 'Dashboard',              'dashboard'),
        ('content_calendar',          'Content Calendar',       'calendar_month'),
        ('analytics',                 'Analytics',              'analytics'),
        ('analytics_charts',          'Analytics Charts',       'bar_chart'),
    ]),
    ('Content', [
        ('hero_slides_list',          'Hero Slides',            'slideshow'),
        ('hero_text_list',            'Hero Text',              'text_fields'),
        ('articles_list',             'Articles',               'article'),
        ('categories_list',           'Categories',             'folder'),
        ('magazines_list',            'Magazines',              'auto_stories'),
        ('feature_cards_list',        'Feature Cards',          'view_carousel'),
        ('facts_list',                'Facts & Quotes',         'lightbulb'),
        ('phrasebook_list',           'Phrasebook',             'translate'),
    ]),
    ('Events', [
        ('events_list',               'Events',                 'event'),
        ('event_registrations_list',  'Event Registrations',    'how_to_reg'),
        ('event_speakers_list',       'Event Speakers',         'mic'),
        ('priority_agendas_list',     'Priority Agendas',       'priority_high'),
    ]),
    ('Media', [
        ('gallery_list',              'Photo Gallery',          'photo_library'),
        ('videos_list',               'Videos',                 'videocam'),
        ('live_feeds_list',           'Live Feeds',             'live_tv'),
    ]),
    ('Notifications & Releases', [
        ('notifications_list',        'Push Notifications',     'notifications'),
        ('app_releases_list',         'App Releases',           'new_releases'),
        ('announcements_list',        'Announcements',          'campaign'),
    ]),
    ('Users & Verification', [
        ('users_list',                'User Management',        'group'),
        ('verification_requests_list','Verification Requests',  'verified'),
    ]),
    ('Continental Dialogue', [
        ('youth_dialogue_list',       'Continental Dialogue',         'forum'),
        ('qr_scan_log',              'QR Scan Log',                  'qr_code_scanner'),
    ]),
    ('Support & Engagement', [
        ('support_tickets_list',      'Support Tickets',        'support_agent'),
        ('polls_list',                'Polls',                  'poll'),
        ('discussions_list',          'Discussions',            'forum'),
        ('comments_list',             'Comments',               'comment'),
    ]),
    ('Emails', [
        ('email_templates_list',      'Email Templates',        'description'),
        ('email_campaigns_list',      'Email Campaigns',        'send'),
        ('email_logs_list',           'Email Logs',             'list_alt'),
        ('email_inbox',               'Email Inbox',            'inbox'),
        ('newsletter_editions_list',  'Newsletters',            'newspaper'),
    ]),
    ('Directory & Locations', [
        ('contact_directory_list',    'Contact Directory',      'contacts'),
        ('social_media_list',         'Social Media Links',     'share'),
        ('weather_cities_list',       'Weather Cities',         'partly_cloudy_day'),
        ('resources_list',            'Resources',              'folder_zip'),
    ]),
    ('Onboarding', [
        ('onboarding_steps_list',     'Onboarding Steps',       'rocket_launch'),
        ('quick_access_list',         'Quick Access Menu',      'apps'),
    ]),
    ('Maintenance', [
        ('maintenance_list',          'Maintenance Windows',    'engineering'),
        ('promotional_splash_list',   'Promotional Splashes',   'ad'),
    ]),
    ('Webhooks', [
        ('webhook_list',              'Webhooks',               'webhook'),
    ]),
    ('Settings', [
        ('app_settings',              'App Settings',           'settings'),
        ('about_features_list',       'About Features',         'info'),
        ('translation_manager',       'Translation Manager',    'translate'),
        ('reorder',                   'Reorder Content',        'swap_vert'),
    ]),
    ('System', [
        ('system_health',             'System Health',          'monitor_heart'),
        ('database_backup',           'Database Backups',       'database'),
        ('error_tracking',            'Error Tracking',         'bug_report'),
        ('rate_limiting',             'Rate Limiting',          'speed'),
    ]),
    ('Audit', [
        ('audit_log',                 'Audit Log',              'history'),
        ('activity_log',              'Activity Log',           'manage_history'),
    ]),
]

# Flat list for backwards-compatible iteration
ADMIN_MENUS = [leaf for _, leaves in ADMIN_MENU_GROUPS for leaf in leaves]
MENU_KEYS = {m[0] for m in ADMIN_MENUS}

# Legacy aliases (kept so existing imports keep working)
ADMIN_SECTIONS = [(k, l, i, '') for (k, l, i) in ADMIN_MENUS]
SECTION_KEYS = MENU_KEYS


# URLs that never require a section check (auth flow, bell notifications,
# and admin_management which is superuser-only via its own decorator).
# IMPORTANT: do NOT add data-bearing or write-capable endpoints here.
# global_search, widget_data, image_editor, etc. are now section-gated.
UNRESTRICTED_URLS = {
    'login', 'logout', '2fa_verify', '2fa_setup',
    'admin_notifications_api', 'admin_notification_mark_read', 'admin_notifications_page',
    # Admin management is superuser-only (enforced by the view decorator)
    'admin_management', 'admin_invite', 'admin_edit_access',
}


def get_required_section(url_name):
    """Return the menu key required for a given custom_admin URL name.

    Each sidebar menu has its own key; CRUD variants map to their parent
    menu via prefix matching. None = no restriction.
    """
    if not url_name:
        return None
    if url_name in UNRESTRICTED_URLS:
        return None

    # Exact match — the menu key is the URL name itself
    if url_name in MENU_KEYS:
        return url_name

    # Dashboard utilities — accessible to any staff (dashboard is always allowed)
    if url_name in {'widget_data', 'global_search', 'global_search_api',
                    'admin_global_search', 'admin_global_search_api'}:
        return 'dashboard'

    # Image editor is a shared tool but requires at least content access
    if url_name in {'image_editor', 'image_crop_save'}:
        return 'articles_list'

    # Media library browser
    if url_name == 'media_library_api':
        return 'gallery_list'

    # A/B tests — analytics-adjacent feature
    if url_name.startswith('ab_test'):
        return 'analytics'

    # Auto-translate — settings/translation feature
    if url_name == 'auto_translate':
        return 'translation_manager'

    # Export user data — requires user management access
    if url_name == 'export_users_csv':
        return 'users_list'

    # Newsletter subscribers — part of newsletter management
    if url_name == 'newsletter_subscribers_list':
        return 'newsletter_editions_list'

    # Dashboard & analytics extras
    if url_name in {'analytics_export_pdf', 'nationality_map', 'export_analytics_csv'}:
        return 'analytics'

    # System / infra
    if 'system_health' in url_name:
        return 'system_health'
    if 'database_backup' in url_name or url_name in {'create_backup', 'download_backup', 'delete_backup'}:
        return 'database_backup'
    if 'error_tracking' in url_name:
        return 'error_tracking'
    if 'rate_limiting' in url_name:
        return 'rate_limiting'

    # Audit / activity
    if 'audit_log' in url_name or url_name == 'admin_audit_log':
        return 'audit_log'
    if 'activity_log' in url_name:
        return 'activity_log'

    # Content — CRUD variants
    if 'hero_slide' in url_name:
        return 'hero_slides_list'
    if 'hero_text' in url_name:
        return 'hero_text_list'
    if 'feature_card' in url_name:
        return 'feature_cards_list'
    if 'magazine' in url_name:
        return 'magazines_list'
    if 'about_feature' in url_name:
        return 'about_features_list'
    if 'fact_categor' in url_name:
        return 'facts_list'
    if url_name.startswith('fact'):
        return 'facts_list'
    if 'phrasebook' in url_name:
        return 'phrasebook_list'
    if 'categor' in url_name:
        return 'categories_list'
    if 'article' in url_name:
        return 'articles_list'

    # Events — CRUD variants
    if 'event_registration' in url_name or 'event_submission' in url_name:
        return 'event_registrations_list'
    if 'event_speaker' in url_name:
        return 'event_speakers_list'
    if 'priority_agenda' in url_name:
        return 'priority_agendas_list'
    if url_name.startswith('event'):
        return 'events_list'

    # Media — CRUD variants
    if 'gallery' in url_name:
        return 'gallery_list'
    if 'live_feed' in url_name:
        return 'live_feeds_list'
    if url_name.startswith('video'):
        return 'videos_list'

    # Notifications & releases
    if url_name.startswith('notification'):
        return 'notifications_list'
    if 'app_release' in url_name:
        return 'app_releases_list'
    if 'announcement' in url_name:
        return 'announcements_list'

    # Users — CRUD + bulk + segments
    if 'segment' in url_name:
        return 'users_list'
    if 'bulk_user' in url_name or 'export_user' in url_name:
        return 'users_list'
    if url_name in {'user_create', 'user_edit', 'user_toggle_active', 'user_toggle_staff'}:
        return 'users_list'

    # Verifications
    if 'verification' in url_name:
        return 'verification_requests_list'

    # QR Scan Log
    if 'qr_scan_log' in url_name or 'scan_log' in url_name:
        return 'qr_scan_log'

    # Youth Dialogue
    if 'youth_dialogue' in url_name:
        return 'youth_dialogue_list'

    # Support
    if 'support_ticket' in url_name:
        return 'support_tickets_list'

    # Engagement
    if 'poll' in url_name:
        return 'polls_list'
    if 'discussion' in url_name:
        return 'discussions_list'
    if 'comment' in url_name:
        return 'comments_list'

    # Emails
    if url_name.startswith('email_template'):
        return 'email_templates_list'
    if url_name.startswith('email_campaign'):
        return 'email_campaigns_list'
    if url_name.startswith('email_log'):
        return 'email_logs_list'
    if url_name.startswith('email_inbox') or url_name == 'email_inbox':
        return 'email_inbox'
    if url_name.startswith('newsletter'):
        return 'newsletter_editions_list'
    if url_name.startswith('email_'):
        return 'email_templates_list'

    # Directory & locations
    if 'contact_directory' in url_name or 'embass' in url_name:
        return 'contact_directory_list'
    if 'social_media' in url_name:
        return 'social_media_list'
    if 'weather' in url_name:
        return 'weather_cities_list'
    if 'resource' in url_name:
        return 'resources_list'

    # Onboarding & quick access
    if 'onboarding' in url_name:
        return 'onboarding_steps_list'
    if 'quick_access' in url_name:
        return 'quick_access_list'

    # Promotional Splashes
    if 'promotional_splash' in url_name:
        return 'promotional_splash_list'

    # Maintenance
    if url_name.startswith('maintenance'):
        return 'maintenance_list'

    # Webhooks
    if 'webhook' in url_name:
        return 'webhook_list'

    # Settings
    if 'app_settings' in url_name:
        return 'app_settings'
    if 'translation' in url_name:
        return 'translation_manager'
    if 'reorder' in url_name or 'bulk_content' in url_name:
        return 'reorder'

    # Unknown → deny (fail-secure). Log so developers notice new URLs
    # that need mapping. Superusers bypass this entirely.
    import logging
    logging.getLogger(__name__).warning(
        'Unmapped custom_admin URL %r — access denied for non-superuser staff',
        url_name,
    )
    return '__unmapped__'


def user_can_access(user, section_key):
    """Return True if the given user may access the given section."""
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    if not user.is_staff:
        return False
    # Dashboard is the landing page — always accessible to any staff user
    if section_key == 'dashboard':
        return True
    try:
        allowed = user.profile.admin_sections or []
    except Exception:
        allowed = []
    return section_key in allowed


# ═══════════════════════════════════════════════════════════════
# Middleware: block direct URL access to un-permitted sections
# ═══════════════════════════════════════════════════════════════
class AdminSectionPermissionMiddleware:
    """Enforces per-section access on all custom_admin URLs.

    - Superusers bypass entirely.
    - Anonymous or non-staff users: pass through (the view-level
      @login_required / @user_passes_test decorators handle them).
    - Staff users: if the resolved URL belongs to the custom_admin
      namespace and maps to a section, check their allowed list.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        if not request.user.is_authenticated:
            return None
        if request.user.is_superuser:
            return None
        if not request.user.is_staff:
            return None

        match = getattr(request, 'resolver_match', None)
        if not match:
            return None
        if match.namespace != 'custom_admin':
            return None

        required = get_required_section(match.url_name)
        if required is None:
            return None

        if user_can_access(request.user, required):
            return None

        # Forbidden
        html = render_to_string(
            'custom_admin/access_denied.html',
            {
                'section_key': required,
                'section_label': dict((s[0], s[1]) for s in ADMIN_SECTIONS).get(required, required),
            },
            request=request,
        )
        return HttpResponseForbidden(html)
