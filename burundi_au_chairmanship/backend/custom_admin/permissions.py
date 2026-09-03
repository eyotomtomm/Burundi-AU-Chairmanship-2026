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
from django.shortcuts import redirect
from django.template.loader import render_to_string


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
        ('news_scraper',              'News Scraper',           'travel_explore'),
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
        ('device_bans_list',          'Device Bans',            'phonelink_erase'),
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
        ('discussion_topics_list',    'Explore Topics',         'forum'),
        ('content_reports_list',      'Reported Content',       'flag'),
        ('emergency_contacts_list',   'Emergency Contacts',     'emergency'),
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
UNRESTRICTED_URLS = {
    'login', 'logout', '2fa_verify', '2fa_setup', 'force_password_change',
    'admin_notifications', 'admin_notifications_api', 'admin_notification_mark_read',
    # Admin management is superuser-only (enforced by the view decorator)
    'admin_management', 'admin_invite', 'admin_edit_access',
}

# URLs reachable while the 2FA / forced-password-change gate is still open.
AUTH_FLOW_URLS = {'login', 'logout', '2fa_verify', '2fa_setup', 'force_password_change'}

# Explicit menu-key -> URL-names map. Every custom_admin URL name must appear
# here or in UNRESTRICTED_URLS (tests enforce this). Unmapped names are denied.
_SECTION_URLS = {
    'dashboard': ('dashboard', 'widget_data', 'global_search', 'global_search_api', 'ping'),
    'content_calendar': ('content_calendar',),
    'analytics': ('analytics', 'analytics_export_pdf', 'nationality_map', 'export_analytics_csv',
                  'ab_test_list', 'ab_test_create', 'ab_test_detail', 'ab_test_edit', 'ab_test_delete'),
    'analytics_charts': ('analytics_charts',),
    'hero_slides_list': ('hero_slides_list', 'hero_slide_create', 'hero_slide_edit', 'hero_slide_delete'),
    'hero_text_list': ('hero_text_list', 'hero_text_create', 'hero_text_edit', 'hero_text_delete'),
    'articles_list': ('articles_list', 'article_create', 'article_edit', 'article_delete',
                      'image_editor', 'image_crop_save'),
    'news_scraper': ('news_scraper', 'news_scraper_review', 'news_sources_list'),
    'categories_list': ('categories_list', 'category_create', 'category_edit', 'category_delete'),
    'magazines_list': ('magazines_list', 'magazine_create', 'magazine_edit', 'magazine_delete'),
    'feature_cards_list': ('feature_cards_list', 'feature_card_create', 'feature_card_edit', 'feature_card_delete'),
    'facts_list': ('facts_list', 'fact_create', 'fact_edit', 'fact_delete', 'fact_toggle_active',
                   'fact_categories_list', 'fact_category_create', 'fact_category_edit', 'fact_category_delete'),
    'phrasebook_list': ('phrasebook_list', 'phrasebook_create', 'phrasebook_edit', 'phrasebook_delete'),
    'events_list': ('events_list', 'event_create', 'event_edit', 'event_toggle_active', 'event_delete'),
    'event_registrations_list': ('event_registrations_list', 'event_registration_create', 'event_registration_edit',
                                 'event_registration_submissions', 'event_registration_delete', 'event_submission_review'),
    'event_speakers_list': ('event_speakers_list', 'event_speaker_create', 'event_speaker_edit', 'event_speaker_delete'),
    'priority_agendas_list': ('priority_agendas_list', 'priority_agenda_create', 'priority_agenda_edit', 'priority_agenda_delete'),
    'gallery_list': ('gallery_list', 'gallery_create', 'gallery_edit', 'gallery_delete', 'media_library_api'),
    'videos_list': ('videos_list', 'video_create', 'video_edit', 'video_delete'),
    'live_feeds_list': ('live_feeds_list', 'live_feed_create', 'live_feed_edit', 'live_feed_delete'),
    'notifications_list': ('notifications_list', 'notification_create', 'notification_edit', 'notification_delete',
                           'notification_send_push', 'notification_estimate_audience', 'push_diagnostics'),
    'app_releases_list': ('app_releases_list', 'app_release_create', 'app_release_edit', 'app_release_delete'),
    'announcements_list': ('announcements_list', 'announcement_create', 'announcement_edit', 'announcement_delete'),
    'users_list': ('users_list', 'user_create', 'user_edit', 'user_toggle_active', 'user_toggle_staff',
                   'user_toggle_comment_ban', 'user_toggle_yd_ban', 'bulk_user_action', 'export_users_csv',
                   'segment_list', 'segment_create', 'segment_detail', 'segment_edit', 'segment_delete',
                   'segment_preview', 'segment_export', 'segment_notify'),
    'device_bans_list': ('device_bans_list', 'device_ban_unban'),
    'verification_requests_list': ('verification_requests_list', 'verification_request_review'),
    'youth_dialogue_list': ('youth_dialogue_list', 'youth_dialogue_event_create', 'youth_dialogue_event_edit',
                            'youth_dialogue_toggle_active', 'youth_dialogue_applications_list',
                            'youth_dialogue_bulk_action', 'youth_dialogue_bulk_auto_approve',
                            'youth_dialogue_batch_accept_docs', 'youth_dialogue_media_list',
                            'youth_dialogue_media_create', 'youth_dialogue_media_edit', 'youth_dialogue_media_delete',
                            'youth_dialogue_review', 'youth_dialogue_export_csv', 'youth_dialogue_export_excel',
                            'youth_dialogue_analytics', 'youth_dialogue_export_analytics_excel',
                            'youth_dialogue_export_id_holders_excel', 'youth_dialogue_id_card_pdf',
                            'youth_dialogue_verify_qr',
                            'reviewer_list', 'reviewer_detail', 'reviewer_action', 'reviewer_set_lang',
                            'reviewer_document_proxy'),
    'qr_scan_log': ('qr_scan_log',),
    'support_tickets_list': ('support_tickets_list', 'support_ticket_detail', 'support_ticket_reply',
                             'support_ticket_update_status'),
    'polls_list': ('polls_list', 'poll_create', 'poll_edit', 'poll_delete'),
    'discussions_list': ('discussions_list', 'discussion_create', 'discussion_toggle_pin', 'discussion_toggle_lock',
                         'discussion_delete'),
    'comments_list': ('comments_list', 'comment_engagement', 'comment_delete', 'comment_bulk_delete',
                      'comment_toggle_ban'),
    'email_templates_list': ('email_templates_list', 'email_template_edit', 'email_template_preview',
                             'email_template_send_test'),
    'email_campaigns_list': ('email_campaigns_list', 'email_campaign_create', 'email_campaign_edit',
                             'email_campaign_send', 'email_campaign_send_confirm', 'email_campaign_delete'),
    'email_logs_list': ('email_logs_list',),
    'email_inbox': ('email_inbox',),
    'newsletter_editions_list': ('newsletter_editions_list', 'newsletter_edition_preview', 'newsletter_send_now',
                                 'newsletter_subscribers_list'),
    'contact_directory_list': ('contact_directory_list', 'contact_directory_create', 'contact_directory_edit',
                               'contact_directory_delete'),
    'discussion_topics_list': ('discussion_topics_list', 'discussion_topic_create', 'discussion_topic_edit',
                               'discussion_topic_delete'),
    'content_reports_list': ('content_reports_list', 'content_report_set_status', 'content_report_delete_post',
                             'content_report_ban_author', 'content_report_restore_post'),
    'emergency_contacts_list': ('emergency_contacts_list', 'emergency_contact_create', 'emergency_contact_edit',
                                'emergency_contact_delete'),
    'social_media_list': ('social_media_list', 'social_media_create', 'social_media_edit', 'social_media_delete'),
    'weather_cities_list': ('weather_cities_list', 'weather_city_create', 'weather_city_edit', 'weather_city_delete'),
    'resources_list': ('resources_list', 'resource_create', 'resource_edit', 'resource_delete'),
    'onboarding_steps_list': ('onboarding_steps_list', 'onboarding_step_create', 'onboarding_step_edit',
                              'onboarding_step_delete'),
    'quick_access_list': ('quick_access_list', 'quick_access_create', 'quick_access_edit', 'quick_access_delete'),
    'maintenance_list': ('maintenance_list', 'maintenance_create', 'maintenance_edit', 'maintenance_delete',
                         'maintenance', 'maintenance_toggle', 'maintenance_schedule'),
    'promotional_splash_list': ('promotional_splash_list', 'promotional_splash_create', 'promotional_splash_edit',
                                'promotional_splash_delete', 'promotional_splash_activate_now'),
    'webhook_list': ('webhook_list', 'webhook_create', 'webhook_edit', 'webhook_delete', 'webhook_toggle',
                     'webhook_logs', 'webhook_test'),
    'app_settings': ('app_settings',),
    'about_features_list': ('about_features_list', 'about_feature_create', 'about_feature_edit',
                            'about_feature_delete'),
    'translation_manager': ('translation_manager', 'translation_queue_list', 'translation_queue_update',
                            'auto_translate'),
    'reorder': ('reorder', 'reorder_save', 'bulk_content_action'),
    'system_health': ('system_health', 'system_health_api'),
    'database_backup': ('database_backup', 'create_backup', 'download_backup', 'delete_backup'),
    'error_tracking': ('error_tracking', 'error_tracking_api'),
    'rate_limiting': ('rate_limiting',),
    'audit_log': ('audit_log',),
    'activity_log': ('activity_log',),
}
URL_SECTIONS = {name: section for section, names in _SECTION_URLS.items() for name in names}


def get_required_section(url_name):
    """Return the menu key required for a custom_admin URL name.

    None = no restriction. Unknown names deny (fail-secure) and are logged so
    developers notice new URLs that need mapping. Superusers bypass entirely.
    """
    if not url_name or url_name in UNRESTRICTED_URLS:
        return None
    section = URL_SECTIONS.get(url_name)
    if section is None:
        import logging
        logging.getLogger(__name__).warning(
            'Unmapped custom_admin URL %r — access denied for non-superuser staff',
            url_name,
        )
        return '__unmapped__'
    return section


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
    """Enforces 2FA, forced password change and per-section access on custom_admin URLs.

    - Anonymous or non-staff users: pass through (the view-level
      @login_required / @user_passes_test decorators handle them).
    - Every staff user (superusers included) must be OTP-verified and not
      flagged force_password_change before reaching anything outside AUTH_FLOW_URLS.
    - Superusers then bypass the section check; other staff need the mapped
      section in profile.admin_sections.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        if not request.user.is_authenticated:
            return None
        if not (request.user.is_staff or request.user.is_superuser):
            return None

        match = getattr(request, 'resolver_match', None)
        if not match or match.namespace != 'custom_admin':
            return None

        # 2FA + forced password change gate — applies to superusers too.
        if match.url_name not in AUTH_FLOW_URLS:
            if not request.user.is_verified():
                from django_otp.plugins.otp_totp.models import TOTPDevice
                has_device = TOTPDevice.objects.devices_for_user(request.user, confirmed=True).exists()
                return redirect('custom_admin:2fa_verify' if has_device else 'custom_admin:2fa_setup')
            if getattr(getattr(request.user, 'profile', None), 'force_password_change', False):
                return redirect('custom_admin:force_password_change')

        if request.user.is_superuser:
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
