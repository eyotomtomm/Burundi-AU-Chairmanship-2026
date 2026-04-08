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

    # Users
    path('users/', views.users_list, name='users_list'),
    path('users/create/', views.user_create, name='user_create'),
    path('users/<int:pk>/edit/', views.user_edit, name='user_edit'),
    path('users/<int:pk>/toggle-active/', views.user_toggle_active, name='user_toggle_active'),
    path('users/<int:pk>/toggle-staff/', views.user_toggle_staff, name='user_toggle_staff'),

    # Admin Management (Superuser only)
    path('admin-management/', views.admin_management, name='admin_management'),
    path('admin-management/invite/', views.admin_invite, name='admin_invite'),

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

    # Audit Log
    path('audit-log/', views.admin_audit_log, name='audit_log'),

    # Bulk Actions
    path('bulk/users/', views.bulk_user_action, name='bulk_user_action'),
    path('bulk/content/', views.bulk_content_action, name='bulk_content_action'),

    # Global Search
    path('search/', views.admin_global_search, name='global_search'),

    # Export Reports
    path('export/users-csv/', views.export_users_csv, name='export_users_csv'),
    path('export/analytics-csv/', views.export_analytics_csv, name='export_analytics_csv'),

    # Translation Manager
    path('translations/', views.translation_manager, name='translation_manager'),
]
