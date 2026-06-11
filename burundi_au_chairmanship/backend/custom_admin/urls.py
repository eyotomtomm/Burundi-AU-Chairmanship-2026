from django.urls import path
from . import views

app_name = 'custom_admin'

urlpatterns = [
    # Auth
    path('', views.admin_login, name='login'),
    path('logout/', views.admin_logout, name='logout'),

    # Dashboard
    path('dashboard/', views.dashboard, name='dashboard'),

    # Hero Slides
    path('hero-slides/', views.hero_slides_list, name='hero_slides_list'),
    path('hero-slides/create/', views.hero_slide_create, name='hero_slide_create'),
    path('hero-slides/<int:pk>/edit/', views.hero_slide_edit, name='hero_slide_edit'),
    path('hero-slides/<int:pk>/delete/', views.hero_slide_delete, name='hero_slide_delete'),

    # Hero Text
    path('hero-text/', views.hero_text_list, name='hero_text_list'),
    path('hero-text/create/', views.hero_text_create, name='hero_text_create'),
    path('hero-text/<int:pk>/edit/', views.hero_text_edit, name='hero_text_edit'),
    path('hero-text/<int:pk>/delete/', views.hero_text_delete, name='hero_text_delete'),

    # Articles
    path('articles/', views.articles_list, name='articles_list'),
    path('articles/create/', views.article_create, name='article_create'),
    path('articles/<int:pk>/edit/', views.article_edit, name='article_edit'),
    path('articles/<int:pk>/delete/', views.article_delete, name='article_delete'),

    # Categories
    path('categories/', views.categories_list, name='categories_list'),
    path('categories/create/', views.category_create, name='category_create'),
    path('categories/<int:pk>/edit/', views.category_edit, name='category_edit'),
    path('categories/<int:pk>/delete/', views.category_delete, name='category_delete'),

    # Events
    path('events/', views.events_list, name='events_list'),
    path('events/create/', views.event_create, name='event_create'),
    path('events/<int:pk>/edit/', views.event_edit, name='event_edit'),
    path('events/<int:pk>/toggle-active/', views.event_toggle_active, name='event_toggle_active'),
    path('events/<int:pk>/delete/', views.event_delete, name='event_delete'),

    # Notifications
    path('notifications/', views.notifications_list, name='notifications_list'),
    path('notifications/create/', views.notification_create, name='notification_create'),
    path('notifications/<int:pk>/edit/', views.notification_edit, name='notification_edit'),
    path('notifications/<int:pk>/delete/', views.notification_delete, name='notification_delete'),
    path('notifications/<int:pk>/send/', views.notification_send_push, name='notification_send_push'),
    path('notifications/estimate-audience/', views.notification_estimate_audience, name='notification_estimate_audience'),

    # App Releases (What's New popup)
    path('app-releases/', views.app_releases_list, name='app_releases_list'),
    path('app-releases/create/', views.app_release_create, name='app_release_create'),
    path('app-releases/<int:pk>/edit/', views.app_release_edit, name='app_release_edit'),
    path('app-releases/<int:pk>/delete/', views.app_release_delete, name='app_release_delete'),

    # Users
    path('users/', views.users_list, name='users_list'),
    path('users/create/', views.user_create, name='user_create'),
    path('users/<int:pk>/edit/', views.user_edit, name='user_edit'),
    path('users/<int:pk>/toggle-active/', views.user_toggle_active, name='user_toggle_active'),
    path('users/<int:pk>/toggle-staff/', views.user_toggle_staff, name='user_toggle_staff'),

    # Admin Management (Superuser only)
    path('admin-management/', views.admin_management, name='admin_management'),
    path('admin-management/invite/', views.admin_invite, name='admin_invite'),
    path('admin-management/<int:pk>/access/', views.admin_edit_access, name='admin_edit_access'),

    # Verification Requests
    path('verification-requests/', views.verification_requests_list, name='verification_requests_list'),
    path('verification-requests/<int:pk>/review/', views.verification_request_review, name='verification_request_review'),

    # Magazines
    path('magazines/', views.magazines_list, name='magazines_list'),
    path('magazines/create/', views.magazine_create, name='magazine_create'),
    path('magazines/<int:pk>/edit/', views.magazine_edit, name='magazine_edit'),
    path('magazines/<int:pk>/delete/', views.magazine_delete, name='magazine_delete'),

    # Feature Cards
    path('feature-cards/', views.feature_cards_list, name='feature_cards_list'),
    path('feature-cards/create/', views.feature_card_create, name='feature_card_create'),
    path('feature-cards/<int:pk>/edit/', views.feature_card_edit, name='feature_card_edit'),
    path('feature-cards/<int:pk>/delete/', views.feature_card_delete, name='feature_card_delete'),

    # Event / Holiday Cards (Event Registrations)
    path('event-registrations/', views.event_registrations_list, name='event_registrations_list'),
    path('event-registrations/create/', views.event_registration_create, name='event_registration_create'),
    path('event-registrations/<int:pk>/edit/', views.event_registration_edit, name='event_registration_edit'),
    path('event-registrations/<int:pk>/submissions/', views.event_registration_submissions, name='event_registration_submissions'),
    path('event-registrations/<int:pk>/delete/', views.event_registration_delete, name='event_registration_delete'),
    path('event-submissions/<int:pk>/review/', views.event_submission_review, name='event_submission_review'),

    # Quick Access Menu
    path('quick-access/', views.quick_access_list, name='quick_access_list'),
    path('quick-access/create/', views.quick_access_create, name='quick_access_create'),
    path('quick-access/<int:pk>/edit/', views.quick_access_edit, name='quick_access_edit'),
    path('quick-access/<int:pk>/delete/', views.quick_access_delete, name='quick_access_delete'),

    # Priority Agendas
    path('priority-agendas/', views.priority_agendas_list, name='priority_agendas_list'),
    path('priority-agendas/create/', views.priority_agenda_create, name='priority_agenda_create'),
    path('priority-agendas/<int:pk>/edit/', views.priority_agenda_edit, name='priority_agenda_edit'),
    path('priority-agendas/<int:pk>/delete/', views.priority_agenda_delete, name='priority_agenda_delete'),

    # Gallery
    path('gallery/', views.gallery_list, name='gallery_list'),
    path('gallery/create/', views.gallery_create, name='gallery_create'),
    path('gallery/<int:pk>/edit/', views.gallery_edit, name='gallery_edit'),
    path('gallery/<int:pk>/delete/', views.gallery_delete, name='gallery_delete'),

    # Videos
    path('videos/', views.videos_list, name='videos_list'),
    path('videos/create/', views.video_create, name='video_create'),
    path('videos/<int:pk>/edit/', views.video_edit, name='video_edit'),
    path('videos/<int:pk>/delete/', views.video_delete, name='video_delete'),

    # Live Feeds
    path('live-feeds/', views.live_feeds_list, name='live_feeds_list'),
    path('live-feeds/create/', views.live_feed_create, name='live_feed_create'),
    path('live-feeds/<int:pk>/edit/', views.live_feed_edit, name='live_feed_edit'),
    path('live-feeds/<int:pk>/delete/', views.live_feed_delete, name='live_feed_delete'),

    # Resources
    path('resources/', views.resources_list, name='resources_list'),
    path('resources/create/', views.resource_create, name='resource_create'),
    path('resources/<int:pk>/edit/', views.resource_edit, name='resource_edit'),
    path('resources/<int:pk>/delete/', views.resource_delete, name='resource_delete'),

    # Social Media
    path('social-media/', views.social_media_list, name='social_media_list'),
    path('social-media/create/', views.social_media_create, name='social_media_create'),
    path('social-media/<int:pk>/edit/', views.social_media_edit, name='social_media_edit'),
    path('social-media/<int:pk>/delete/', views.social_media_delete, name='social_media_delete'),

    # Weather Cities
    path('weather-cities/', views.weather_cities_list, name='weather_cities_list'),
    path('weather-cities/create/', views.weather_city_create, name='weather_city_create'),
    path('weather-cities/<int:pk>/edit/', views.weather_city_edit, name='weather_city_edit'),
    path('weather-cities/<int:pk>/delete/', views.weather_city_delete, name='weather_city_delete'),

    # App Settings
    path('app-settings/', views.app_settings, name='app_settings'),

    # Support Tickets
    path('support/', views.support_tickets_list, name='support_tickets_list'),
    path('support/<int:pk>/', views.support_ticket_detail, name='support_ticket_detail'),
    path('support/<int:pk>/reply/', views.support_ticket_reply, name='support_ticket_reply'),
    path('support/<int:pk>/status/', views.support_ticket_update_status, name='support_ticket_update_status'),

    # Analytics
    path('analytics/', views.analytics_dashboard, name='analytics'),
    path('analytics/export-pdf/', views.analytics_export_pdf, name='analytics_export_pdf'),
    path('analytics/nationality/', views.nationality_map, name='nationality_map'),
    path('analytics/rate-limiting/', views.rate_limiting_dashboard, name='rate_limiting'),
    path('analytics/charts/', views.analytics_charts, name='analytics_charts'),

    # Polls
    path('polls/', views.polls_list, name='polls_list'),
    path('polls/create/', views.poll_create, name='poll_create'),
    path('polls/<int:pk>/edit/', views.poll_edit, name='poll_edit'),
    path('polls/<int:pk>/delete/', views.poll_delete, name='poll_delete'),

    # Discussions / Forums
    path('discussions/', views.discussions_list, name='discussions_list'),
    path('discussions/<int:pk>/toggle-pin/', views.discussion_toggle_pin, name='discussion_toggle_pin'),
    path('discussions/<int:pk>/toggle-lock/', views.discussion_toggle_lock, name='discussion_toggle_lock'),
    path('discussions/<int:pk>/delete/', views.discussion_delete, name='discussion_delete'),

    # Contact Directory
    path('contact-directory/', views.contact_directory_list, name='contact_directory_list'),
    path('contact-directory/create/', views.contact_directory_create, name='contact_directory_create'),
    path('contact-directory/<int:pk>/edit/', views.contact_directory_edit, name='contact_directory_edit'),
    path('contact-directory/<int:pk>/delete/', views.contact_directory_delete, name='contact_directory_delete'),

    # Email Templates
    path('email-templates/', views.email_templates_list, name='email_templates_list'),
    path('email-templates/<int:pk>/edit/', views.email_template_edit, name='email_template_edit'),

    # Email Campaigns (marketing blasts)
    path('email-campaigns/', views.email_campaigns_list, name='email_campaigns_list'),
    path('email-campaigns/create/', views.email_campaign_create, name='email_campaign_create'),
    path('email-campaigns/<int:pk>/edit/', views.email_campaign_edit, name='email_campaign_edit'),
    path('email-campaigns/<int:pk>/send/', views.email_campaign_send, name='email_campaign_send'),
    path('email-campaigns/<int:pk>/delete/', views.email_campaign_delete, name='email_campaign_delete'),

    # Email Logs (sent + failed history)
    path('email-logs/', views.email_logs_list, name='email_logs_list'),

    # Email Inbox (IMAP viewer)
    path('email-inbox/', views.email_inbox, name='email_inbox'),

    # Newsletter Editions
    path('newsletters/', views.newsletter_editions_list, name='newsletter_editions_list'),
    path('newsletters/<int:pk>/preview/', views.newsletter_edition_preview, name='newsletter_edition_preview'),
    path('newsletters/send-now/', views.newsletter_send_now, name='newsletter_send_now'),

    # Newsletter Subscribers
    path('newsletter-subscribers/', views.newsletter_subscribers_list, name='newsletter_subscribers_list'),

    # Announcement Banners
    path('announcements/', views.announcements_list, name='announcements_list'),
    path('announcements/create/', views.announcement_create, name='announcement_create'),
    path('announcements/<int:pk>/edit/', views.announcement_edit, name='announcement_edit'),
    path('announcements/<int:pk>/delete/', views.announcement_delete, name='announcement_delete'),

    # Event Speakers
    path('event-speakers/', views.event_speakers_list, name='event_speakers_list'),
    path('event-speakers/create/', views.event_speaker_create, name='event_speaker_create'),
    path('event-speakers/<int:pk>/edit/', views.event_speaker_edit, name='event_speaker_edit'),
    path('event-speakers/<int:pk>/delete/', views.event_speaker_delete, name='event_speaker_delete'),

    # Onboarding Steps
    path('onboarding/', views.onboarding_steps_list, name='onboarding_steps_list'),
    path('onboarding/create/', views.onboarding_step_create, name='onboarding_step_create'),
    path('onboarding/<int:pk>/edit/', views.onboarding_step_edit, name='onboarding_step_edit'),
    path('onboarding/<int:pk>/delete/', views.onboarding_step_delete, name='onboarding_step_delete'),

    # Scheduled Maintenance
    path('maintenance/', views.maintenance_list, name='maintenance_list'),
    path('maintenance/create/', views.maintenance_create, name='maintenance_create'),
    path('maintenance/<int:pk>/edit/', views.maintenance_edit, name='maintenance_edit'),
    path('maintenance/<int:pk>/delete/', views.maintenance_delete, name='maintenance_delete'),

    # Promotional Splashes
    path('promotional-splashes/', views.promotional_splash_list, name='promotional_splash_list'),
    path('promotional-splashes/create/', views.promotional_splash_create, name='promotional_splash_create'),
    path('promotional-splashes/<int:pk>/edit/', views.promotional_splash_edit, name='promotional_splash_edit'),
    path('promotional-splashes/<int:pk>/delete/', views.promotional_splash_delete, name='promotional_splash_delete'),

    # Audit Log
    path('audit-log/', views.admin_audit_log, name='audit_log'),

    # Bulk Actions
    path('bulk/users/', views.bulk_user_action, name='bulk_user_action'),
    path('bulk/content/', views.bulk_content_action, name='bulk_content_action'),

    # Global Search
    path('search/', views.admin_global_search, name='global_search'),
    path('search/api/', views.admin_global_search_api, name='global_search_api'),

    # Export Reports
    path('export/users-csv/', views.export_users_csv, name='export_users_csv'),
    path('export/analytics-csv/', views.export_analytics_csv, name='export_analytics_csv'),

    # Translation Manager
    path('translations/', views.translation_manager, name='translation_manager'),

    # Activity Log
    path('activity-log/', views.activity_log, name='activity_log'),

    # User Segments
    path('segments/', views.segment_list, name='segment_list'),
    path('segments/create/', views.segment_create, name='segment_create'),
    path('segments/<int:pk>/', views.segment_detail, name='segment_detail'),
    path('segments/<int:pk>/edit/', views.segment_edit, name='segment_edit'),
    path('segments/<int:pk>/delete/', views.segment_delete, name='segment_delete'),
    path('segments/preview/', views.segment_preview, name='segment_preview'),
    path('segments/<int:pk>/export/', views.segment_export, name='segment_export'),
    path('segments/<int:pk>/notify/', views.segment_notify, name='segment_notify'),

    # System Health
    path('system-health/', views.system_health_dashboard, name='system_health'),
    path('system-health/api/', views.system_health_api, name='system_health_api'),

    # Database Backups
    path('database/backups/', views.database_backup_page, name='database_backup'),
    path('database/backups/create/', views.create_backup, name='create_backup'),
    path('database/backups/<int:pk>/download/', views.download_backup, name='download_backup'),
    path('database/backups/<int:pk>/delete/', views.delete_backup, name='delete_backup'),

    # Admin Notifications (Bell)
    path('admin-notifications/', views.admin_notifications_page, name='admin_notifications'),
    path('admin-notifications/api/', views.admin_notifications_api, name='admin_notifications_api'),
    path('admin-notifications/mark-read/', views.admin_notification_mark_read, name='admin_notification_mark_read'),

    # Image Editor / Cropper
    path('image-editor/', views.image_editor, name='image_editor'),
    path('image-editor/save/', views.image_crop_save, name='image_crop_save'),

    # Dashboard Widget Data (AJAX)
    path('dashboard/widget/', views.widget_data, name='widget_data'),

    # Email Template Preview & Send Test (AJAX)
    path('email-templates/<int:pk>/preview/', views.email_template_preview, name='email_template_preview'),
    path('email-templates/<int:pk>/send-test/', views.email_template_send_test, name='email_template_send_test'),

    # Content Calendar
    path('content-calendar/', views.content_calendar, name='content_calendar'),

    # Drag & Drop Reorder
    path('reorder/', views.reorder_page, name='reorder'),
    path('reorder/save/', views.reorder_save, name='reorder_save'),

    # Scheduled Maintenance Management
    path('maintenance/management/', views.maintenance_management, name='maintenance'),
    path('maintenance/toggle/', views.maintenance_toggle, name='maintenance_toggle'),
    path('maintenance/schedule/', views.maintenance_schedule, name='maintenance_schedule'),

    # A/B Tests
    path('ab-tests/', views.ab_test_list, name='ab_test_list'),
    path('ab-tests/create/', views.ab_test_create, name='ab_test_create'),
    path('ab-tests/<int:pk>/', views.ab_test_detail, name='ab_test_detail'),
    path('ab-tests/<int:pk>/edit/', views.ab_test_edit, name='ab_test_edit'),
    path('ab-tests/<int:pk>/delete/', views.ab_test_delete, name='ab_test_delete'),

    # Webhooks
    path('webhooks/', views.webhook_list, name='webhook_list'),
    path('webhooks/create/', views.webhook_create, name='webhook_create'),
    path('webhooks/<int:pk>/edit/', views.webhook_edit, name='webhook_edit'),
    path('webhooks/<int:pk>/delete/', views.webhook_delete, name='webhook_delete'),
    path('webhooks/<int:pk>/toggle/', views.webhook_toggle, name='webhook_toggle'),
    path('webhooks/<int:pk>/logs/', views.webhook_logs, name='webhook_logs'),
    path('webhooks/<int:pk>/test/', views.webhook_test, name='webhook_test'),

    # Translation Queue
    path('translation-queue/', views.translation_queue_list, name='translation_queue_list'),
    path('translation-queue/<int:pk>/update/', views.translation_queue_update, name='translation_queue_update'),

    # Comments Management
    path('comments/', views.comments_list, name='comments_list'),
    path('comments/<int:pk>/delete/', views.comment_delete, name='comment_delete'),
    path('comments/bulk-delete/', views.comment_bulk_delete, name='comment_bulk_delete'),

    # Error Tracking (Sentry)
    path('error-tracking/', views.error_tracking_dashboard, name='error_tracking'),
    path('error-tracking/api/', views.error_tracking_api, name='error_tracking_api'),

    # Auto-translate (EN <-> FR)
    path('translate/', views.auto_translate, name='auto_translate'),

    # Media Library (Browse existing Spaces images)
    path('media-library/api/', views.media_library_api, name='media_library_api'),

    # Youth Dialogue
    path('youth-dialogue/', views.youth_dialogue_list, name='youth_dialogue_list'),
    path('youth-dialogue/settings/', views.youth_dialogue_settings, name='youth_dialogue_settings'),
    path('youth-dialogue/<int:pk>/review/', views.youth_dialogue_review, name='youth_dialogue_review'),
    path('youth-dialogue/export-csv/', views.youth_dialogue_export_csv, name='youth_dialogue_export_csv'),
    path('youth-dialogue/<int:pk>/id-card-pdf/', views.youth_dialogue_id_card_pdf, name='youth_dialogue_id_card_pdf'),

]
