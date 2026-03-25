from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

router = DefaultRouter()
router.register('hero-slides', views.HeroSlideViewSet)
router.register('magazines', views.MagazineEditionViewSet)
router.register('articles', views.ArticleViewSet, basename='article')
router.register('embassies', views.EmbassyLocationViewSet)
router.register('events', views.EventViewSet)
router.register('live-feeds', views.LiveFeedViewSet)
router.register('resources', views.ResourceViewSet)
router.register('feature-cards', views.FeatureCardViewSet)
router.register('categories', views.CategoryViewSet)
router.register('priority-agendas', views.PriorityAgendaViewSet)
router.register('gallery', views.GalleryAlbumViewSet)
router.register('videos', views.VideoViewSet)
router.register('social-media', views.SocialMediaLinkViewSet)
router.register('weather-cities', views.WeatherCityViewSet)
router.register('notifications', views.NotificationViewSet, basename='notification')
router.register('hero-text-content', views.HeroTextContentViewSet)
router.register('quick-access-menu', views.QuickAccessMenuViewSet)
router.register('event-registrations', views.EventRegistrationViewSet, basename='event-registration')
router.register('event-submissions', views.EventSubmissionViewSet, basename='event-submission')
router.register('support/tickets', views.SupportTicketViewSet, basename='support-ticket')

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

    # Auth - Profile management
    path('auth/profile/', views.profile, name='auth-profile'),
    path('auth/profile/update/', views.update_profile, name='auth-profile-update'),
    path('auth/deactivate-account/', views.deactivate_account, name='auth-deactivate-account'),
    path('auth/delete-account/', views.delete_account, name='auth-delete-account'),
    path('auth/reactivate-account/', views.reactivate_account, name='auth-reactivate-account'),
    path('auth/export-data/', views.export_user_data, name='auth-export-data'),

    # Sign-Up Email Verification
    path('auth/send-signup-otp/', views.send_signup_otp, name='auth-send-signup-otp'),
    path('auth/verify-signup-otp/', views.verify_signup_otp, name='auth-verify-signup-otp'),

    # OTP Verification (for badge verification flow)
    path('otp/send-email/', views.send_email_otp, name='otp-send-email'),
    path('otp/verify-email/', views.verify_email_otp, name='otp-verify-email'),
    path('otp/send-phone/', views.send_phone_otp, name='otp-send-phone'),
    path('otp/verify-phone/', views.verify_phone_otp, name='otp-verify-phone'),

    # Event registrations
    path('my-registrations/', views.my_event_registrations, name='my-registrations'),

    # Support Tickets
    path('support/unread-count/', views.support_unread_count, name='support-unread-count'),

    # Verification System
    path('verification/request/', views.submit_verification_request, name='verification-request'),
    path('verification/status/', views.check_verification_status, name='verification-status'),
    path('verification/appeal/', views.submit_verification_appeal, name='verification-appeal'),
    path('verification/admin/<int:request_id>/action/', views.admin_verification_action, name='verification-admin-action'),
]
