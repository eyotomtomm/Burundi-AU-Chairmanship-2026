from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import views
from . import analytics_views

router = DefaultRouter()
router.register('hero-slides', views.HeroSlideViewSet)
router.register('magazines', views.MagazineEditionViewSet)
router.register('articles', views.ArticleViewSet, basename='article')
router.register('events', views.EventViewSet)
router.register('live-feeds', views.LiveFeedViewSet, basename='live-feed')
router.register('resources', views.ResourceViewSet)
router.register('feature-cards', views.FeatureCardViewSet)
router.register('categories', views.CategoryViewSet)
router.register('priority-agendas', views.PriorityAgendaViewSet)
router.register('gallery', views.GalleryAlbumViewSet, basename='galleryalbum')
router.register('videos', views.VideoViewSet, basename='video')
router.register('social-media', views.SocialMediaLinkViewSet)
router.register('weather-cities', views.WeatherCityViewSet)
router.register('notifications', views.NotificationViewSet, basename='notification')
router.register('hero-text-content', views.HeroTextContentViewSet)
router.register('quick-access-menu', views.QuickAccessMenuViewSet)
router.register('event-registrations', views.EventRegistrationViewSet, basename='event-registration')
router.register('event-submissions', views.EventSubmissionViewSet, basename='event-submission')
router.register('support/tickets', views.SupportTicketViewSet, basename='support-ticket')
router.register('popups', views.PopupViewSet, basename='popup')

# New ViewSet routes
router.register('bookmarks', views.BookmarkViewSet, basename='bookmark')
router.register('article-series', views.ArticleSeriesViewSet, basename='article-series')
router.register('event-reminders', views.EventReminderViewSet, basename='event-reminder')
router.register('event-speakers', views.EventSpeakerViewSet, basename='event-speaker')
router.register('event-photos', views.EventPhotoViewSet, basename='event-photo')
router.register('conversations', views.ConversationViewSet, basename='conversation')
router.register('discussions', views.DiscussionViewSet, basename='discussion')
router.register('polls', views.PollViewSet, basename='poll')
router.register('announcement-banners', views.AnnouncementBannerViewSet, basename='announcement-banner')
router.register('contact-directory', views.ContactDirectoryViewSet, basename='contact-directory')
router.register('live-qa', views.LiveQAViewSet, basename='live-qa')
router.register('onboarding-steps', views.OnboardingStepViewSet, basename='onboarding-step')
router.register('event-agenda-items', views.EventAgendaItemViewSet, basename='event-agenda-item')
router.register('youth-dialogue', views.YouthDialogueViewSet, basename='youth-dialogue')

urlpatterns = [
    path('', include(router.urls)),
    path('health/', views.health_check, name='health-check'),  # For load balancers/monitoring
    path('settings/', views.app_settings, name='app-settings'),
    path('home-feed/', views.home_feed, name='home-feed'),

    # Search endpoints
    path('search/articles/', views.search_articles, name='search-articles'),
    path('search/magazines/', views.search_magazines, name='search-magazines'),

    # Auth - Legacy JWT endpoints (for backward compatibility)
    path('auth/register/', views.register, name='auth-register'),
    path('auth/login/', views.login, name='auth-login'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='auth-refresh'),

    # Auth - Firebase endpoints (new)
    path('auth/firebase-register/', views.firebase_register, name='firebase-register'),
    path('auth/firebase-login/', views.firebase_login, name='firebase-login'),
    path('auth/update-fcm-token/', views.update_fcm_token, name='update-fcm-token'),
    path('register-fcm-token/', views.register_fcm_token, name='register-fcm-token'),
    path('auth/deactivate-fcm-token/', views.deactivate_fcm_token, name='deactivate-fcm-token'),
    path('auth/update-device-info/', views.update_device_info, name='update-device-info'),
    path('auth/update-language/', views.update_language_preference, name='update-language'),
    path('heartbeat/', views.heartbeat, name='heartbeat'),
    path('app-open/', views.record_app_open, name='app-open'),

    # Auth - Profile management
    path('auth/profile/', views.profile, name='auth-profile'),
    path('auth/profile/update/', views.update_profile, name='auth-profile-update'),
    path('auth/deactivate-account/', views.deactivate_account, name='auth-deactivate-account'),
    path('auth/delete-account/', views.delete_account, name='auth-delete-account'),
    path('auth/reactivate-account/', views.reactivate_account, name='auth-reactivate-account'),
    path('auth/export-data/', views.export_user_data, name='auth-export-data'),

    # Auth - Security (NEW)
    path('auth/change-password/', views.change_password, name='auth-change-password'),
    path('auth/login-history/', views.login_history, name='auth-login-history'),
    path('auth/active-sessions/', views.active_sessions, name='auth-active-sessions'),
    path('auth/sessions/<int:session_id>/revoke/', views.revoke_session, name='auth-revoke-session'),

    # Sign-Up Email Verification
    path('auth/send-signup-otp/', views.send_signup_otp, name='auth-send-signup-otp'),
    path('auth/verify-signup-otp/', views.verify_signup_otp, name='auth-verify-signup-otp'),

    # OTP Verification (for badge verification flow)
    path('otp/send-email/', views.send_email_otp, name='otp-send-email'),
    path('otp/verify-email/', views.verify_email_otp, name='otp-verify-email'),

    # QR Code Verification
    path('verify-qr/', views.verify_qr, name='verify-qr'),

    # Event registrations
    path('my-registrations/', views.my_event_registrations, name='my-registrations'),

    # Support Tickets
    path('support/unread-count/', views.support_unread_count, name='support-unread-count'),

    # Verification System
    path('verification/request/', views.submit_verification_request, name='verification-request'),
    path('verification/status/', views.check_verification_status, name='verification-status'),
    path('verification/appeal/', views.submit_verification_appeal, name='verification-appeal'),
    path('verification/admin/<int:request_id>/action/', views.admin_verification_action, name='verification-admin-action'),

    # Content Features (NEW)
    path('reactions/toggle/', views.toggle_reaction, name='toggle-reaction'),
    path('reactions/', views.get_reactions, name='get-reactions'),
    path('reading-progress/', views.update_reading_progress, name='reading-progress'),
    path('trending/', views.trending_content, name='trending-content'),

    # Events Features (NEW)
    path('events/feedback/', views.submit_event_feedback, name='event-feedback'),
    path('events/checkin/', views.event_checkin, name='event-checkin'),
    path('events/waitlist/', views.join_event_waitlist, name='event-waitlist'),

    # Communication (NEW)
    path('notification-preferences/', views.notification_preferences, name='notification-preferences'),
    path('notifications/target-count/', views.notification_target_count, name='notification-target-count'),

    # User Preferences & Onboarding (NEW)
    path('preferences/', views.user_preferences, name='user-preferences'),
    path('onboarding/complete/', views.complete_onboarding, name='complete-onboarding'),

    # Infrastructure (NEW)
    path('maintenance/', views.maintenance_status, name='maintenance-status'),
    path('app-update/', views.check_app_update, name='check-app-update'),

    # Promotional Splash
    path('promotional-splash/active/', views.active_promotional_splash, name='active-promotional-splash'),
    path('promotional-splash/<int:pk>/click/', views.track_promotional_splash_click, name='track-promotional-splash-click'),

    # Admin Audit & Management (NEW)
    path('admin/audit-log/', views.admin_audit_log, name='admin-audit-log'),
    path('admin/translations/', views.translation_entries, name='translation-entries'),
    path('admin/translations/<int:pk>/', views.translation_entry_detail, name='translation-entry-detail'),
    path('admin/auto-translate/', views.auto_translate, name='auto-translate'),
    path('admin/drafts/', views.article_drafts, name='article-drafts'),
    path('admin/drafts/<int:pk>/', views.article_draft_detail, name='article-draft-detail'),
    path('admin/content-versions/', views.content_versions, name='content-versions'),
    path('admin/generate-report/', views.generate_weekly_report, name='generate-weekly-report'),

    # Article Share Cards (#34)
    path('articles/<int:pk>/share/', views.article_share_card, name='article-share-card'),

    # Article Revisions (#40)
    path('admin/articles/<int:pk>/revisions/', views.article_revisions, name='article-revisions'),
    path('admin/articles/<int:pk>/revisions/<int:revision_id>/restore/', views.article_revision_restore, name='article-revision-restore'),

    # Translation Queue (#46)
    path('admin/translation-queue/', views.translation_queue, name='translation-queue'),
    path('admin/translation-queue/<int:pk>/', views.translation_queue_detail, name='translation-queue-detail'),

    # Account Linking
    path('auth/linked-accounts/', views.linked_accounts_list, name='linked-accounts-list'),
    path('auth/link-account/', views.link_account, name='link-account'),
    path('auth/unlink-account/', views.unlink_account, name='unlink-account'),
    path('auth/merge-accounts/', views.merge_accounts, name='merge-accounts'),

    # User Features (NEW)
    path('auth/merge-account/', views.request_account_merge, name='request-account-merge'),
    path('password-strength/', views.validate_password_strength, name='password-strength'),
    path('profile-completion/', views.profile_completion, name='profile-completion'),
    path('whats-new/', views.whats_new, name='whats-new'),
    path('events/<int:event_id>/comments/', views.event_comments, name='event-comments'),
    path('events/<int:event_id>/comments/<int:comment_id>/', views.event_comment_delete, name='event-comment-delete'),
    path('events/<int:event_id>/comments/<int:comment_id>/edit/', views.event_comment_edit, name='event-comment-edit'),
    path('events/<int:event_id>/comments/<int:comment_id>/toggle-like/', views.event_comment_toggle_like, name='event-comment-toggle-like'),
    path('events/<int:event_id>/attendees/', views.event_attendees, name='event-attendees'),

    # Newsletter
    path('newsletter/toggle/', views.toggle_newsletter, name='toggle-newsletter'),
    path('newsletter/subscribe/', views.subscribe_newsletter, name='newsletter-subscribe'),
    path('newsletter/check/', views.check_newsletter_subscription, name='newsletter-check'),
    path('newsletter/unsubscribe/<str:token>/', views.newsletter_unsubscribe, name='newsletter-unsubscribe'),

    # Youth Dialogue Admin
    path('youth-dialogue/admin/<int:app_id>/id-card-pdf/', views.yd_id_card_pdf, name='yd-id-card-pdf'),

    # Analytics API (admin only)
    path('analytics/overview/', analytics_views.analytics_overview, name='analytics-overview'),
    path('analytics/user-growth/', analytics_views.analytics_user_growth, name='analytics-user-growth'),
    path('analytics/countries/', analytics_views.analytics_countries, name='analytics-countries'),
    path('analytics/content-engagement/', analytics_views.analytics_content_engagement, name='analytics-content-engagement'),
    path('analytics/export-pdf/', analytics_views.analytics_export_pdf, name='analytics-export-pdf'),
]
