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

    # Embassies
    path('embassies/', views.embassies_list, name='embassies_list'),
    path('embassies/create/', views.embassy_create, name='embassy_create'),
    path('embassies/<int:pk>/edit/', views.embassy_edit, name='embassy_edit'),
    path('embassies/<int:pk>/delete/', views.embassy_delete, name='embassy_delete'),

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

    # Analytics
    path('analytics/', views.analytics_dashboard, name='analytics'),
]
