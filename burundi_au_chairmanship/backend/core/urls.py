from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

router = DefaultRouter()
router.register('hero-slides', views.HeroSlideViewSet)
router.register('magazines', views.MagazineEditionViewSet)
router.register('articles', views.ArticleViewSet)
router.register('embassies', views.EmbassyLocationViewSet)
router.register('events', views.EventViewSet)
router.register('live-feeds', views.LiveFeedViewSet)
router.register('resources', views.ResourceViewSet)
router.register('emergency-contacts', views.EmergencyContactViewSet)
router.register('feature-cards', views.FeatureCardViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('settings/', views.app_settings, name='app-settings'),
    path('home-feed/', views.home_feed, name='home-feed'),

    # Auth
    path('auth/register/', views.register, name='auth-register'),
    path('auth/login/', views.login, name='auth-login'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='auth-refresh'),
    path('auth/profile/', views.profile, name='auth-profile'),
    path('auth/profile/update/', views.update_profile, name='auth-profile-update'),
    path('auth/delete-account/', views.delete_account, name='auth-delete-account'),
    path('auth/export-data/', views.export_user_data, name='auth-export-data'),
]
