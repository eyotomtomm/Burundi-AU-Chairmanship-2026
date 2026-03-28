import logging
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib import messages
from django.db.models import Count, Q
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.core.paginator import Paginator
from django.utils import timezone
from django.core.exceptions import ValidationError

logger = logging.getLogger(__name__)
from core.models import (
    HeroSlide, FeatureCard, Article, MagazineEdition, Event,
    LiveFeed, Video, GalleryAlbum, GalleryPhoto, EmbassyLocation, Resource,
    Notification, Category, PriorityAgenda, SocialMediaLink,
    QuickAccessMenuItem, HeroTextContent, WeatherCity,
    EventRegistration, EventSubmission, RegistrationFormField, AppSettings, User,
    UserProfile, VerificationRequest,
    FeatureCardKeyPoint, FeatureCardImpactArea, FeatureCardMedia,
    AuditLogEntry, SupportTicket, TicketMessage,
)


def is_staff(user):
    return user.is_staff or user.is_superuser


def admin_login(request):
    if request.user.is_authenticated and is_staff(request.user):
        return redirect('custom_admin:dashboard')

    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)

        if user and is_staff(user):
            login(request, user)
            return redirect('custom_admin:dashboard')
        else:
            messages.error(request, 'Invalid credentials or insufficient permissions')

    return render(request, 'custom_admin/login.html')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_logout(request):
    logout(request)
    return redirect('custom_admin:login')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def dashboard(request):
    from datetime import timedelta
    users_count = User.objects.count()
    articles_count = Article.objects.count()
    events_count = Event.objects.count()
    magazines_count = MagazineEdition.objects.count()
    hero_slides_count = HeroSlide.objects.filter(is_active=True).count()
    live_feeds_active = LiveFeed.objects.filter(status='live').count()
    total_content = articles_count + events_count + magazines_count + hero_slides_count
    active_today = User.objects.filter(last_login__gte=timezone.now() - timedelta(days=1)).count()

    stats = {
        'users': users_count,
        'articles': articles_count,
        'events': events_count,
        'magazines': magazines_count,
        'hero_slides': hero_slides_count,
        'feature_cards': FeatureCard.objects.filter(is_active=True).count(),
        'live_feeds_active': live_feeds_active,
        'active_today': active_today,
        'total_content': total_content or 1,
        'recent_articles': Article.objects.order_by('-created_at')[:5],
        'recent_events': Event.objects.order_by('-event_date')[:5],
    }
    return render(request, 'custom_admin/dashboard.html', stats)


# ═══════════════════════════════════════════════════════════════
#  HERO SLIDES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slides_list(request):
    slides = HeroSlide.objects.all().order_by('order')
    return render(request, 'custom_admin/hero_slides/list.html', {'slides': slides})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slide_create(request):
    if request.method == 'POST':
        try:
            slide = HeroSlide(
                label=request.POST.get('label'),
                label_fr=request.POST.get('label_fr', ''),
                image=request.FILES.get('image'),
                order=request.POST.get('order', 0),
                is_active=request.POST.get('is_active') == 'on'
            )
            slide.full_clean()
            slide.save()
            messages.success(request, 'Hero slide created successfully!')
            return redirect('custom_admin:hero_slides_list')
        except ValidationError as e:
            for field, errors in e.message_dict.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
        except Exception as e:
            logger.exception('Hero slide create failed')
            messages.error(request, f'Failed to save hero slide: {e}')
    return render(request, 'custom_admin/hero_slides/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slide_edit(request, pk):
    slide = get_object_or_404(HeroSlide, pk=pk)
    if request.method == 'POST':
        try:
            slide.label = request.POST.get('label')
            slide.label_fr = request.POST.get('label_fr', '')
            if request.FILES.get('image'):
                slide.image = request.FILES.get('image')
            slide.order = request.POST.get('order', 0)
            slide.is_active = request.POST.get('is_active') == 'on'
            slide.full_clean()
            slide.save()
            messages.success(request, 'Hero slide updated successfully!')
            return redirect('custom_admin:hero_slides_list')
        except ValidationError as e:
            for field, errors in e.message_dict.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
        except Exception as e:
            logger.exception('Hero slide edit failed')
            messages.error(request, f'Failed to save hero slide: {e}')
    return render(request, 'custom_admin/hero_slides/form.html', {'slide': slide, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def hero_slide_delete(request, pk):
    slide = get_object_or_404(HeroSlide, pk=pk)
    slide.delete()
    messages.success(request, 'Hero slide deleted successfully!')
    return redirect('custom_admin:hero_slides_list')


# ═══════════════════════════════════════════════════════════════
#  HERO TEXT CONTENT
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_list(request):
    items = HeroTextContent.objects.all().order_by('order')
    return render(request, 'custom_admin/hero_text/list.html', {'items': items})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_create(request):
    if request.method == 'POST':
        HeroTextContent.objects.create(
            key=request.POST.get('key'),
            text_en=request.POST.get('text_en'),
            text_fr=request.POST.get('text_fr', ''),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on'
        )
        messages.success(request, 'Hero text created successfully!')
        return redirect('custom_admin:hero_text_list')
    return render(request, 'custom_admin/hero_text/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_edit(request, pk):
    item = get_object_or_404(HeroTextContent, pk=pk)
    if request.method == 'POST':
        item.key = request.POST.get('key')
        item.text_en = request.POST.get('text_en')
        item.text_fr = request.POST.get('text_fr', '')
        item.order = request.POST.get('order', 0)
        item.is_active = request.POST.get('is_active') == 'on'
        item.save()
        messages.success(request, 'Hero text updated successfully!')
        return redirect('custom_admin:hero_text_list')
    return render(request, 'custom_admin/hero_text/form.html', {'item': item, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def hero_text_delete(request, pk):
    item = get_object_or_404(HeroTextContent, pk=pk)
    item.delete()
    messages.success(request, 'Hero text deleted successfully!')
    return redirect('custom_admin:hero_text_list')


# ═══════════════════════════════════════════════════════════════
#  ARTICLES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def articles_list(request):
    articles = Article.objects.all().select_related('category').order_by('-created_at')
    search = request.GET.get('search')
    if search:
        articles = articles.filter(
            Q(title__icontains=search) | Q(title_fr__icontains=search) | Q(content__icontains=search)
        )
    paginator = Paginator(articles, 20)
    page = request.GET.get('page')
    articles = paginator.get_page(page)
    return render(request, 'custom_admin/articles/list.html', {'articles': articles})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def article_create(request):
    categories = Category.objects.all()
    if request.method == 'POST':
        Article.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            content=request.POST.get('content'),
            content_fr=request.POST.get('content_fr', ''),
            category_id=request.POST.get('category') if request.POST.get('category') else None,
            image=request.FILES.get('image'),
            author=request.POST.get('author', 'Admin'),
            publish_date=request.POST.get('publish_date') or timezone.now(),
            is_featured=request.POST.get('is_featured') == 'on',
        )
        messages.success(request, 'Article created successfully!')
        return redirect('custom_admin:articles_list')
    return render(request, 'custom_admin/articles/form.html', {'categories': categories, 'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def article_edit(request, pk):
    article = get_object_or_404(Article, pk=pk)
    categories = Category.objects.all()
    if request.method == 'POST':
        article.title = request.POST.get('title')
        article.title_fr = request.POST.get('title_fr', '')
        article.content = request.POST.get('content')
        article.content_fr = request.POST.get('content_fr', '')
        article.category_id = request.POST.get('category') if request.POST.get('category') else None
        article.author = request.POST.get('author', article.author)
        if request.FILES.get('image'):
            article.image = request.FILES.get('image')
        article.is_featured = request.POST.get('is_featured') == 'on'
        article.save()
        messages.success(request, 'Article updated successfully!')
        return redirect('custom_admin:articles_list')
    return render(request, 'custom_admin/articles/form.html', {
        'article': article, 'categories': categories, 'action': 'Edit'
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def article_delete(request, pk):
    article = get_object_or_404(Article, pk=pk)
    article.delete()
    messages.success(request, 'Article deleted successfully!')
    return redirect('custom_admin:articles_list')


# ═══════════════════════════════════════════════════════════════
#  CATEGORIES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def categories_list(request):
    categories = Category.objects.all().annotate(article_count=Count('articles'))
    return render(request, 'custom_admin/categories/list.html', {'categories': categories})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def category_create(request):
    if request.method == 'POST':
        Category.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            color=request.POST.get('color', '#1EB53A'),
            order=request.POST.get('order', 0),
        )
        messages.success(request, 'Category created successfully!')
        return redirect('custom_admin:categories_list')
    return render(request, 'custom_admin/categories/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def category_edit(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if request.method == 'POST':
        category.name = request.POST.get('name')
        category.name_fr = request.POST.get('name_fr', '')
        category.color = request.POST.get('color', '#1EB53A')
        category.order = request.POST.get('order', 0)
        category.save()
        messages.success(request, 'Category updated successfully!')
        return redirect('custom_admin:categories_list')
    return render(request, 'custom_admin/categories/form.html', {'category': category, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def category_delete(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if category.articles.exists():
        messages.error(request, 'Cannot delete category with articles. Reassign articles first.')
        return redirect('custom_admin:categories_list')
    category.delete()
    messages.success(request, 'Category deleted successfully!')
    return redirect('custom_admin:categories_list')


# ═══════════════════════════════════════════════════════════════
#  EVENTS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def events_list(request):
    events = Event.objects.all().order_by('-event_date')
    status_filter = request.GET.get('status')
    if status_filter == 'active':
        events = events.filter(is_active=True)
    elif status_filter == 'inactive':
        events = events.filter(is_active=False)

    total_count = Event.objects.count()
    active_count = Event.objects.filter(is_active=True).count()
    inactive_count = Event.objects.filter(is_active=False).count()

    paginator = Paginator(events, 20)
    page = request.GET.get('page')
    events = paginator.get_page(page)
    return render(request, 'custom_admin/events/list.html', {
        'events': events,
        'total_count': total_count,
        'active_count': active_count,
        'inactive_count': inactive_count,
        'current_filter': status_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_create(request):
    if request.method == 'POST':
        Event.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            address=request.POST.get('address'),
            latitude=request.POST.get('latitude', 0),
            longitude=request.POST.get('longitude', 0),
            event_date=request.POST.get('event_date'),
            image=request.FILES.get('image'),
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Event created successfully!')
        return redirect('custom_admin:events_list')
    return render(request, 'custom_admin/events/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_edit(request, pk):
    event = get_object_or_404(Event, pk=pk)
    if request.method == 'POST':
        event.name = request.POST.get('name')
        event.name_fr = request.POST.get('name_fr', '')
        event.description = request.POST.get('description', '')
        event.description_fr = request.POST.get('description_fr', '')
        event.address = request.POST.get('address')
        event.latitude = request.POST.get('latitude', 0)
        event.longitude = request.POST.get('longitude', 0)
        event.event_date = request.POST.get('event_date')
        if request.FILES.get('image'):
            event.image = request.FILES.get('image')
        event.is_active = request.POST.get('is_active') == 'on'
        event.save()
        messages.success(request, 'Event updated successfully!')
        return redirect('custom_admin:events_list')
    return render(request, 'custom_admin/events/form.html', {'event': event, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_toggle_active(request, pk):
    event = get_object_or_404(Event, pk=pk)
    event.is_active = not event.is_active
    event.save()
    status = 'visible in app' if event.is_active else 'hidden from app'
    messages.success(request, f'Event "{event.name}" is now {status}.')
    return redirect('custom_admin:events_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_delete(request, pk):
    event = get_object_or_404(Event, pk=pk)
    event.delete()
    messages.success(request, 'Event deleted successfully!')
    return redirect('custom_admin:events_list')


# ═══════════════════════════════════════════════════════════════
#  NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def notifications_list(request):
    notifications = Notification.objects.all().order_by('-created_at')
    paginator = Paginator(notifications, 20)
    page = request.GET.get('page')
    notifications = paginator.get_page(page)
    return render(request, 'custom_admin/notifications/list.html', {'notifications': notifications})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def notification_create(request):
    if request.method == 'POST':
        notification = Notification.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            message=request.POST.get('message'),
            message_fr=request.POST.get('message_fr', ''),
            notification_type=request.POST.get('notification_type', 'general'),
            action_type=request.POST.get('action_type', 'none'),
            action_value=request.POST.get('action_value', ''),
            is_global=request.POST.get('is_global') == 'on',
            is_active=request.POST.get('is_active') == 'on',
            image=request.FILES.get('image'),
            target_gender=request.POST.get('target_gender', ''),
            target_nationalities=request.POST.getlist('target_nationalities'),
            target_age_min=int(request.POST['target_age_min']) if request.POST.get('target_age_min') else None,
            target_age_max=int(request.POST['target_age_max']) if request.POST.get('target_age_max') else None,
            target_verified_only=request.POST.get('target_verified_only') == 'on',
            target_badge_type=request.POST.get('target_badge_type', ''),
        )
        # Send push notification if requested
        send_push = request.POST.get('send_push') == 'on'
        if send_push and notification.is_active:
            try:
                from core.push_service import send_push_notification
                success, failure = send_push_notification(notification)
                messages.success(
                    request,
                    f'Notification created and push sent to {success} device(s).'
                    + (f' ({failure} failed)' if failure else '')
                )
            except Exception as e:
                messages.warning(request, f'Notification created but push failed: {e}')
        else:
            messages.success(request, 'Notification created successfully!')
        return redirect('custom_admin:notifications_list')
    from core.models import NATIONALITY_CHOICES
    return render(request, 'custom_admin/notifications/form.html', {
        'action': 'Create',
        'nationality_choices': NATIONALITY_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def notification_edit(request, pk):
    notification = get_object_or_404(Notification, pk=pk)
    if request.method == 'POST':
        notification.title = request.POST.get('title')
        notification.title_fr = request.POST.get('title_fr', '')
        notification.message = request.POST.get('message')
        notification.message_fr = request.POST.get('message_fr', '')
        notification.notification_type = request.POST.get('notification_type', 'general')
        notification.action_type = request.POST.get('action_type', 'none')
        notification.action_value = request.POST.get('action_value', '')
        notification.is_global = request.POST.get('is_global') == 'on'
        notification.is_active = request.POST.get('is_active') == 'on'
        if request.FILES.get('image'):
            notification.image = request.FILES['image']
        notification.target_gender = request.POST.get('target_gender', '')
        notification.target_nationalities = request.POST.getlist('target_nationalities')
        notification.target_age_min = int(request.POST['target_age_min']) if request.POST.get('target_age_min') else None
        notification.target_age_max = int(request.POST['target_age_max']) if request.POST.get('target_age_max') else None
        notification.target_verified_only = request.POST.get('target_verified_only') == 'on'
        notification.target_badge_type = request.POST.get('target_badge_type', '')
        notification.save()
        # Send push if explicitly requested on edit
        send_push = request.POST.get('send_push') == 'on'
        if send_push and notification.is_active:
            try:
                from core.push_service import send_push_notification
                success, failure = send_push_notification(notification)
                messages.success(
                    request,
                    f'Notification updated and push sent to {success} device(s).'
                    + (f' ({failure} failed)' if failure else '')
                )
            except Exception as e:
                messages.warning(request, f'Notification updated but push failed: {e}')
        else:
            messages.success(request, 'Notification updated successfully!')
        return redirect('custom_admin:notifications_list')
    from core.models import NATIONALITY_CHOICES
    return render(request, 'custom_admin/notifications/form.html', {
        'notification': notification,
        'action': 'Edit',
        'nationality_choices': NATIONALITY_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def notification_delete(request, pk):
    notification = get_object_or_404(Notification, pk=pk)
    notification.delete()
    messages.success(request, 'Notification deleted successfully!')
    return redirect('custom_admin:notifications_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def notification_send_push(request, pk):
    """Send (or resend) a push notification for an existing notification."""
    notification = get_object_or_404(Notification, pk=pk)
    if not notification.is_active:
        messages.error(request, 'Cannot send push for an inactive notification. Activate it first.')
        return redirect('custom_admin:notifications_list')
    try:
        from core.push_service import send_push_notification
        success, failure = send_push_notification(notification)
        messages.success(
            request,
            f'Push sent to {success} device(s).'
            + (f' ({failure} failed)' if failure else '')
        )
    except Exception as e:
        messages.error(request, f'Push notification failed: {e}')
    return redirect('custom_admin:notifications_list')


# ═══════════════════════════════════════════════════════════════
#  USERS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def users_list(request):
    users = User.objects.all().select_related('profile').order_by('-date_joined')
    search = request.GET.get('search')
    if search:
        users = users.filter(
            Q(username__icontains=search) | Q(email__icontains=search) |
            Q(first_name__icontains=search) | Q(last_name__icontains=search)
        )
    # Filter by status
    status_filter = request.GET.get('status')
    if status_filter == 'active':
        users = users.filter(is_active=True)
    elif status_filter == 'blocked':
        users = users.filter(is_active=False)
    elif status_filter == 'staff':
        users = users.filter(is_staff=True)
    elif status_filter == 'verified':
        users = users.filter(profile__is_verified=True)

    total_count = User.objects.count()
    active_count = User.objects.filter(is_active=True).count()
    blocked_count = User.objects.filter(is_active=False).count()
    staff_count = User.objects.filter(is_staff=True).count()
    verified_count = UserProfile.objects.filter(is_verified=True).count()
    pending_verifications = VerificationRequest.objects.filter(status='pending').count()

    paginator = Paginator(users, 20)
    page = request.GET.get('page')
    users = paginator.get_page(page)
    return render(request, 'custom_admin/users/list.html', {
        'users': users,
        'total_count': total_count,
        'active_count': active_count,
        'blocked_count': blocked_count,
        'staff_count': staff_count,
        'verified_count': verified_count,
        'pending_verifications': pending_verifications,
        'current_filter': status_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def user_create(request):
    if request.method == 'POST':
        username = request.POST.get('username')
        email = request.POST.get('email')
        password = request.POST.get('password')
        first_name = request.POST.get('first_name', '')
        last_name = request.POST.get('last_name', '')

        if User.objects.filter(username=username).exists():
            messages.error(request, f'Username "{username}" already exists.')
            return render(request, 'custom_admin/users/form.html', {'action': 'Create'})
        if email and User.objects.filter(email=email).exists():
            messages.error(request, f'Email "{email}" already in use.')
            return render(request, 'custom_admin/users/form.html', {'action': 'Create'})

        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        user.is_staff = request.POST.get('is_staff') == 'on'
        user.is_active = request.POST.get('is_active') != 'off'
        user.save()
        messages.success(request, f'User "{username}" created successfully!')
        return redirect('custom_admin:users_list')
    return render(request, 'custom_admin/users/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def user_edit(request, pk):
    target_user = get_object_or_404(User, pk=pk)
    profile = getattr(target_user, 'profile', None)
    if not profile:
        profile = UserProfile.objects.create(user=target_user)

    if request.method == 'POST':
        target_user.first_name = request.POST.get('first_name', '')
        target_user.last_name = request.POST.get('last_name', '')
        target_user.email = request.POST.get('email', '')
        target_user.is_active = request.POST.get('is_active') == 'on'
        # Only superusers can modify staff status
        if request.user.is_superuser:
            target_user.is_staff = request.POST.get('is_staff') == 'on'

        new_password = request.POST.get('password', '').strip()
        if new_password:
            target_user.set_password(new_password)

        target_user.save()

        # Profile fields
        profile.phone_number = request.POST.get('phone_number', '')
        profile.nationality = request.POST.get('nationality', '')
        profile.gender = request.POST.get('gender', '')
        profile.is_verified = request.POST.get('is_verified') == 'on'
        profile.badge_type = request.POST.get('badge_type') or None
        profile.is_government_official = request.POST.get('is_government_official') == 'on'
        profile.save()

        messages.success(request, f'User "{target_user.username}" updated successfully!')
        return redirect('custom_admin:users_list')

    verification_requests = VerificationRequest.objects.filter(user=target_user).order_by('-created_at')
    return render(request, 'custom_admin/users/form.html', {
        'target_user': target_user,
        'profile': profile,
        'verification_requests': verification_requests,
        'action': 'Edit',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def user_toggle_active(request, pk):
    target_user = get_object_or_404(User, pk=pk)
    if target_user == request.user:
        messages.error(request, 'You cannot block yourself.')
        return redirect('custom_admin:users_list')
    target_user.is_active = not target_user.is_active
    target_user.save()
    action = 'unblocked' if target_user.is_active else 'blocked'
    messages.success(request, f'User "{target_user.username}" has been {action}.')
    return redirect('custom_admin:users_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def user_toggle_staff(request, pk):
    # Only superusers can modify staff status
    if not request.user.is_superuser:
        messages.error(request, 'Only superusers can modify staff permissions.')
        return redirect('custom_admin:users_list')
    target_user = get_object_or_404(User, pk=pk)
    if target_user == request.user:
        messages.error(request, 'You cannot remove your own staff status.')
        return redirect('custom_admin:users_list')
    target_user.is_staff = not target_user.is_staff
    target_user.save()
    action = 'granted staff access' if target_user.is_staff else 'removed from staff'
    messages.success(request, f'User "{target_user.username}" {action}.')
    return redirect('custom_admin:users_list')


# ═══════════════════════════════════════════════════════════════
#  VERIFICATION REQUESTS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def verification_requests_list(request):
    requests_qs = VerificationRequest.objects.all().select_related('user', 'reviewed_by').order_by('-created_at')
    status_filter = request.GET.get('status')
    if status_filter:
        requests_qs = requests_qs.filter(status=status_filter)
    paginator = Paginator(requests_qs, 20)
    page = request.GET.get('page')
    requests_page = paginator.get_page(page)
    pending_count = VerificationRequest.objects.filter(status='pending').count()
    return render(request, 'custom_admin/verification/list.html', {
        'requests': requests_page,
        'pending_count': pending_count,
        'current_filter': status_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def verification_request_review(request, pk):
    ver_request = get_object_or_404(VerificationRequest, pk=pk)
    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'approve':
            badge_type = request.POST.get('badge_type', 'BLUE')
            ver_request.status = 'approved'
            ver_request.badge_type = badge_type
            ver_request.reviewed_by = request.user
            ver_request.reviewed_at = timezone.now()
            ver_request.save()
            # Update user profile
            profile = ver_request.user.profile
            profile.is_verified = True
            profile.badge_type = badge_type
            profile.verified_at = timezone.now()
            profile.save()
            messages.success(request, f'Approved {ver_request.full_name} with {badge_type} badge.')
        elif action == 'reject':
            ver_request.status = 'rejected'
            ver_request.rejection_reason = request.POST.get('rejection_reason', '')
            ver_request.reviewed_by = request.user
            ver_request.reviewed_at = timezone.now()
            ver_request.save()
            messages.success(request, f'Rejected verification request from {ver_request.full_name}.')
        return redirect('custom_admin:verification_requests_list')
    return render(request, 'custom_admin/verification/review.html', {'ver_request': ver_request})


# ═══════════════════════════════════════════════════════════════
#  MAGAZINES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def magazines_list(request):
    magazines = MagazineEdition.objects.all().order_by('-publish_date')
    paginator = Paginator(magazines, 20)
    page = request.GET.get('page')
    magazines = paginator.get_page(page)
    return render(request, 'custom_admin/magazines/list.html', {'magazines': magazines})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def magazine_create(request):
    if request.method == 'POST':
        MagazineEdition.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            cover_image=request.FILES.get('cover_image'),
            pdf_file=request.FILES.get('pdf_file'),
            page_count=request.POST.get('page_count', 0),
            file_size=request.POST.get('file_size', ''),
            publish_date=request.POST.get('publish_date') or timezone.now().date(),
            is_featured=request.POST.get('is_featured') == 'on',
        )
        messages.success(request, 'Magazine created successfully!')
        return redirect('custom_admin:magazines_list')
    return render(request, 'custom_admin/magazines/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def magazine_edit(request, pk):
    magazine = get_object_or_404(MagazineEdition, pk=pk)
    if request.method == 'POST':
        magazine.title = request.POST.get('title')
        magazine.title_fr = request.POST.get('title_fr', '')
        magazine.description = request.POST.get('description', '')
        magazine.description_fr = request.POST.get('description_fr', '')
        if request.FILES.get('cover_image'):
            magazine.cover_image = request.FILES.get('cover_image')
        if request.FILES.get('pdf_file'):
            magazine.pdf_file = request.FILES.get('pdf_file')
        magazine.page_count = request.POST.get('page_count', 0)
        magazine.file_size = request.POST.get('file_size', '')
        magazine.is_featured = request.POST.get('is_featured') == 'on'
        magazine.save()
        messages.success(request, 'Magazine updated successfully!')
        return redirect('custom_admin:magazines_list')
    return render(request, 'custom_admin/magazines/form.html', {'magazine': magazine, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def magazine_delete(request, pk):
    magazine = get_object_or_404(MagazineEdition, pk=pk)
    magazine.delete()
    messages.success(request, 'Magazine deleted successfully!')
    return redirect('custom_admin:magazines_list')


# ═══════════════════════════════════════════════════════════════
#  FEATURE CARDS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def feature_cards_list(request):
    cards = FeatureCard.objects.all().order_by('order')
    return render(request, 'custom_admin/feature_cards/list.html', {'cards': cards})


def _save_feature_card_children(request, card):
    """Save key points, impact areas, and media from form arrays."""
    # --- Key Points ---
    card.key_point_items.all().delete()
    kp_texts = request.POST.getlist('kp_text[]')
    kp_texts_fr = request.POST.getlist('kp_text_fr[]')
    for i, text in enumerate(kp_texts):
        text = text.strip()
        if not text:
            continue
        FeatureCardKeyPoint.objects.create(
            feature_card=card,
            text=text,
            text_fr=kp_texts_fr[i].strip() if i < len(kp_texts_fr) else '',
            order=i,
        )

    # --- Impact Areas ---
    card.impact_area_items.all().delete()
    ia_icons = request.POST.getlist('ia_icon[]')
    ia_titles = request.POST.getlist('ia_title[]')
    ia_titles_fr = request.POST.getlist('ia_title_fr[]')
    ia_descs = request.POST.getlist('ia_desc[]')
    ia_descs_fr = request.POST.getlist('ia_desc_fr[]')
    for i, title in enumerate(ia_titles):
        title = title.strip()
        if not title:
            continue
        FeatureCardImpactArea.objects.create(
            feature_card=card,
            icon_name=ia_icons[i] if i < len(ia_icons) else 'stars',
            title=title,
            title_fr=ia_titles_fr[i].strip() if i < len(ia_titles_fr) else '',
            description=ia_descs[i].strip() if i < len(ia_descs) else '',
            description_fr=ia_descs_fr[i].strip() if i < len(ia_descs_fr) else '',
            order=i,
        )

    # --- Media ---
    card.media.all().delete()
    media_types = request.POST.getlist('media_type[]')
    media_urls = request.POST.getlist('media_url[]')
    media_captions = request.POST.getlist('media_caption[]')
    media_captions_fr = request.POST.getlist('media_caption_fr[]')
    # Map file inputs by index (image uploads or video uploads)
    media_file_map = {}
    for key, f in request.FILES.items():
        if key.startswith('media_file_'):
            try:
                idx = int(key.replace('media_file_', ''))
                media_file_map[idx] = f
            except ValueError:
                pass

    for i, mtype in enumerate(media_types):
        mtype = mtype.strip()
        if not mtype:
            continue
        url = media_urls[i].strip() if i < len(media_urls) else ''
        caption = media_captions[i].strip() if i < len(media_captions) else ''
        caption_fr = media_captions_fr[i].strip() if i < len(media_captions_fr) else ''
        uploaded_file = media_file_map.get(i)

        # Need at least a file or a URL
        if not uploaded_file and not url:
            continue

        kwargs = {
            'feature_card': card,
            'media_type': mtype,
            'caption': caption,
            'caption_fr': caption_fr,
            'order': i,
        }
        if mtype == 'image':
            if uploaded_file:
                kwargs['image'] = uploaded_file
            else:
                kwargs['image_url'] = url
        else:  # video
            if uploaded_file:
                kwargs['video_file'] = uploaded_file
            else:
                kwargs['video_url'] = url

        FeatureCardMedia.objects.create(**kwargs)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def feature_card_create(request):
    if request.method == 'POST':
        card = FeatureCard.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            image=request.FILES.get('image'),
            icon_image=request.FILES.get('icon_image'),
            icon_name=request.POST.get('icon_name', ''),
            gradient_start=request.POST.get('gradient_start', '#1EB53A'),
            gradient_end=request.POST.get('gradient_end', '#4CAF50'),
            overview=request.POST.get('overview', ''),
            overview_fr=request.POST.get('overview_fr', ''),
            extra_content=request.POST.get('extra_content', ''),
            extra_content_fr=request.POST.get('extra_content_fr', ''),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on',
        )
        _save_feature_card_children(request, card)
        messages.success(request, 'Feature card created successfully!')
        return redirect('custom_admin:feature_cards_list')
    icon_choices = FeatureCard.ICON_CHOICES
    return render(request, 'custom_admin/feature_cards/form.html', {'action': 'Create', 'icon_choices': icon_choices})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def feature_card_edit(request, pk):
    card = get_object_or_404(FeatureCard, pk=pk)
    if request.method == 'POST':
        card.title = request.POST.get('title')
        card.title_fr = request.POST.get('title_fr', '')
        card.description = request.POST.get('description', '')
        card.description_fr = request.POST.get('description_fr', '')
        if request.FILES.get('image'):
            card.image = request.FILES.get('image')
        if request.FILES.get('icon_image'):
            card.icon_image = request.FILES.get('icon_image')
        card.icon_name = request.POST.get('icon_name', '')
        card.gradient_start = request.POST.get('gradient_start', '#1EB53A')
        card.gradient_end = request.POST.get('gradient_end', '#4CAF50')
        card.overview = request.POST.get('overview', '')
        card.overview_fr = request.POST.get('overview_fr', '')
        card.extra_content = request.POST.get('extra_content', '')
        card.extra_content_fr = request.POST.get('extra_content_fr', '')
        card.order = request.POST.get('order', 0)
        card.is_active = request.POST.get('is_active') == 'on'
        card.save()
        _save_feature_card_children(request, card)
        messages.success(request, 'Feature card updated successfully!')
        return redirect('custom_admin:feature_cards_list')
    icon_choices = FeatureCard.ICON_CHOICES
    key_points = list(card.key_point_items.all().values('text', 'text_fr'))
    impact_areas = list(card.impact_area_items.all().values('icon_name', 'title', 'title_fr', 'description', 'description_fr'))
    media_items = [
        {
            'media_type': m.media_type,
            'effective_url': m.effective_image_url if m.media_type == 'image' else m.effective_video_url,
            'caption': m.caption,
            'caption_fr': m.caption_fr,
        }
        for m in card.media.all()
    ]
    return render(request, 'custom_admin/feature_cards/form.html', {
        'card': card,
        'action': 'Edit',
        'icon_choices': icon_choices,
        'key_points': key_points,
        'impact_areas': impact_areas,
        'media_items': media_items,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def feature_card_delete(request, pk):
    card = get_object_or_404(FeatureCard, pk=pk)
    card.delete()
    messages.success(request, 'Feature card deleted successfully!')
    return redirect('custom_admin:feature_cards_list')


# ═══════════════════════════════════════════════════════════════
#  EVENT REGISTRATIONS (Event / Holiday Cards)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registrations_list(request):
    registrations = EventRegistration.objects.all().annotate(
        submission_count=Count('submissions')
    )
    card_type_filter = request.GET.get('type')
    if card_type_filter:
        registrations = registrations.filter(card_type=card_type_filter)
    return render(request, 'custom_admin/event_registrations/list.html', {
        'registrations': registrations,
        'current_filter': card_type_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def _save_form_fields(request, reg):
    """Parse and save inline form fields from the event registration form."""
    import json as _json
    # Delete removed fields
    existing_ids = set(reg.form_fields.values_list('id', flat=True))
    kept_ids = set()
    idx = 0
    while True:
        prefix = f'field_{idx}_'
        field_type = request.POST.get(f'{prefix}type')
        if field_type is None:
            break
        field_id = request.POST.get(f'{prefix}id')
        field_label = request.POST.get(f'{prefix}label', '')
        field_label_fr = request.POST.get(f'{prefix}label_fr', '')
        field_name = request.POST.get(f'{prefix}name', '')
        placeholder = request.POST.get(f'{prefix}placeholder', '')
        placeholder_fr = request.POST.get(f'{prefix}placeholder_fr', '')
        is_required = request.POST.get(f'{prefix}required') == 'on'
        is_active = request.POST.get(f'{prefix}active') == 'on'
        help_text = request.POST.get(f'{prefix}help_text', '')
        help_text_fr = request.POST.get(f'{prefix}help_text_fr', '')
        options_str = request.POST.get(f'{prefix}options', '')
        validation_regex = request.POST.get(f'{prefix}validation_regex', '')
        order = idx

        # Parse options: comma-separated or JSON array
        options = []
        if options_str.strip():
            try:
                options = _json.loads(options_str)
            except (ValueError, TypeError):
                options = [o.strip() for o in options_str.split(',') if o.strip()]

        data = {
            'event_registration': reg,
            'field_type': field_type,
            'field_label': field_label,
            'field_label_fr': field_label_fr,
            'field_name': field_name,
            'placeholder': placeholder,
            'placeholder_fr': placeholder_fr,
            'is_required': is_required,
            'is_active': is_active,
            'options': options,
            'help_text': help_text,
            'help_text_fr': help_text_fr,
            'validation_regex': validation_regex,
            'order': order,
        }

        if field_id and field_id.isdigit():
            fid = int(field_id)
            RegistrationFormField.objects.filter(pk=fid, event_registration=reg).update(**{
                k: v for k, v in data.items() if k != 'event_registration'
            })
            kept_ids.add(fid)
        else:
            obj = RegistrationFormField.objects.create(**data)
            kept_ids.add(obj.pk)
        idx += 1

    # Delete fields that were removed
    to_delete = existing_ids - kept_ids
    if to_delete:
        RegistrationFormField.objects.filter(pk__in=to_delete).delete()


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registration_create(request):
    if request.method == 'POST':
        reg = EventRegistration.objects.create(
            card_type=request.POST.get('card_type', 'event'),
            event_title=request.POST.get('event_title', ''),
            event_title_fr=request.POST.get('event_title_fr', ''),
            event_description=request.POST.get('event_description', ''),
            event_description_fr=request.POST.get('event_description_fr', ''),
            event_poster=request.FILES.get('event_poster'),
            event_date=request.POST.get('event_date') or None,
            event_end_date=request.POST.get('event_end_date') or None,
            venue=request.POST.get('venue', ''),
            venue_fr=request.POST.get('venue_fr', ''),
            venue_address=request.POST.get('venue_address', ''),
            contact_email=request.POST.get('contact_email', ''),
            contact_phone=request.POST.get('contact_phone', ''),
            is_registration_enabled=request.POST.get('is_registration_enabled') == 'on',
            registration_deadline=request.POST.get('registration_deadline') or None,
            max_registrations=request.POST.get('max_registrations') or 0,
            allow_proxy_registration=request.POST.get('allow_proxy_registration') == 'on',
            send_confirmation_email=request.POST.get('send_confirmation_email') == 'on',
            confirmation_message=request.POST.get('confirmation_message', ''),
            confirmation_message_fr=request.POST.get('confirmation_message_fr', ''),
            is_active=request.POST.get('is_active') == 'on',
            order=request.POST.get('order') or 0,
        )
        _save_form_fields(request, reg)
        messages.success(request, 'Event created successfully!')
        return redirect('custom_admin:event_registrations_list')
    return render(request, 'custom_admin/event_registrations/form.html', {
        'action': 'Create',
        'field_type_choices': RegistrationFormField.FIELD_TYPE_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registration_edit(request, pk):
    reg = get_object_or_404(EventRegistration, pk=pk)
    if request.method == 'POST':
        reg.card_type = request.POST.get('card_type', 'event')
        reg.event_title = request.POST.get('event_title', '')
        reg.event_title_fr = request.POST.get('event_title_fr', '')
        reg.event_description = request.POST.get('event_description', '')
        reg.event_description_fr = request.POST.get('event_description_fr', '')
        if request.FILES.get('event_poster'):
            reg.event_poster = request.FILES.get('event_poster')
        reg.event_date = request.POST.get('event_date') or None
        reg.event_end_date = request.POST.get('event_end_date') or None
        reg.venue = request.POST.get('venue', '')
        reg.venue_fr = request.POST.get('venue_fr', '')
        reg.venue_address = request.POST.get('venue_address', '')
        reg.contact_email = request.POST.get('contact_email', '')
        reg.contact_phone = request.POST.get('contact_phone', '')
        reg.is_registration_enabled = request.POST.get('is_registration_enabled') == 'on'
        reg.registration_deadline = request.POST.get('registration_deadline') or None
        reg.max_registrations = request.POST.get('max_registrations') or 0
        reg.allow_proxy_registration = request.POST.get('allow_proxy_registration') == 'on'
        reg.send_confirmation_email = request.POST.get('send_confirmation_email') == 'on'
        reg.confirmation_message = request.POST.get('confirmation_message', '')
        reg.confirmation_message_fr = request.POST.get('confirmation_message_fr', '')
        reg.is_active = request.POST.get('is_active') == 'on'
        reg.order = request.POST.get('order') or 0
        reg.save()
        _save_form_fields(request, reg)
        messages.success(request, 'Event updated successfully!')
        return redirect('custom_admin:event_registrations_list')

    import json as _json
    # Prepare existing fields as JSON for the template
    existing_fields = list(reg.form_fields.order_by('order').values(
        'id', 'field_type', 'field_label', 'field_label_fr', 'field_name',
        'placeholder', 'placeholder_fr', 'is_required', 'is_active',
        'options', 'help_text', 'help_text_fr', 'validation_regex', 'order',
    ))
    return render(request, 'custom_admin/event_registrations/form.html', {
        'reg': reg,
        'action': 'Edit',
        'field_type_choices': RegistrationFormField.FIELD_TYPE_CHOICES,
        'existing_fields_json': _json.dumps(existing_fields, default=str),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registration_submissions(request, pk):
    import csv as _csv
    from django.http import HttpResponse

    reg = get_object_or_404(EventRegistration, pk=pk)
    qs = EventSubmission.objects.filter(event_registration=reg).select_related('user').order_by('-submitted_at')
    status_filter = request.GET.get('status')
    if status_filter:
        qs = qs.filter(status=status_filter)

    # CSV export
    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="submissions_{reg.pk}.csv"'
        # Build field name → label mapping
        field_map = {f.field_name: f.field_label for f in reg.form_fields.all()}
        # Collect all form data keys across submissions
        all_keys = []
        for sub in qs:
            if sub.form_data:
                for k in sub.form_data.keys():
                    if k not in all_keys:
                        all_keys.append(k)

        writer = _csv.writer(response)
        header = ['#', 'User', 'Email', 'Status', 'Submitted At', 'Is Proxy', 'Proxy Name', 'Proxy Email', 'Proxy Phone']
        header += [field_map.get(k, k.replace('_', ' ').title()) for k in all_keys]
        writer.writerow(header)
        for i, sub in enumerate(qs, 1):
            row = [
                i,
                sub.user.username,
                sub.user.email or '',
                sub.get_status_display(),
                sub.submitted_at.strftime('%Y-%m-%d %H:%M'),
                'Yes' if sub.is_proxy else 'No',
                sub.proxy_name or '',
                sub.proxy_email or '',
                sub.proxy_phone or '',
            ]
            for k in all_keys:
                val = sub.form_data.get(k, '') if sub.form_data else ''
                if isinstance(val, list):
                    val = ', '.join(str(v) for v in val)
                row.append(val)
            writer.writerow(row)
        return response

    paginator = Paginator(qs, 20)
    page = request.GET.get('page')
    submissions = paginator.get_page(page)
    return render(request, 'custom_admin/event_registrations/submissions.html', {
        'reg': reg,
        'submissions': submissions,
        'current_filter': status_filter or 'all',
        'total_count': EventSubmission.objects.filter(event_registration=reg).count(),
        'pending_count': EventSubmission.objects.filter(event_registration=reg, status='pending').count(),
        'approved_count': EventSubmission.objects.filter(event_registration=reg, status='approved').count(),
        'rejected_count': EventSubmission.objects.filter(event_registration=reg, status='rejected').count(),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_submission_review(request, pk):
    submission = get_object_or_404(EventSubmission.objects.select_related('event_registration', 'user', 'reviewed_by'), pk=pk)
    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'approve':
            submission.status = 'approved'
            submission.admin_notes = request.POST.get('admin_notes', '')
            submission.reviewed_by = request.user
            submission.reviewed_at = timezone.now()
            submission.save()
            messages.success(request, f'Submission from {submission.user.username} approved.')
        elif action == 'reject':
            submission.status = 'rejected'
            submission.admin_notes = request.POST.get('admin_notes', '')
            submission.reviewed_by = request.user
            submission.reviewed_at = timezone.now()
            submission.save()
            messages.success(request, f'Submission from {submission.user.username} rejected.')
        return redirect('custom_admin:event_registration_submissions', pk=submission.event_registration.pk)

    # Map field_name → field_label for friendly display
    field_map = {f.field_name: f.field_label for f in submission.event_registration.form_fields.all()}
    field_labels = {}
    if submission.form_data:
        from collections import OrderedDict
        field_labels = OrderedDict()
        for key, value in submission.form_data.items():
            friendly = field_map.get(key, key.replace('_', ' ').title())
            # Format list values (multi_checkbox)
            if isinstance(value, list):
                value = ', '.join(str(v) for v in value)
            field_labels[friendly] = value

    return render(request, 'custom_admin/event_registrations/submission_review.html', {
        'submission': submission,
        'field_labels': field_labels,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_registration_delete(request, pk):
    reg = get_object_or_404(EventRegistration, pk=pk)
    reg.delete()
    messages.success(request, 'Event/Holiday card deleted successfully!')
    return redirect('custom_admin:event_registrations_list')


# ═══════════════════════════════════════════════════════════════
#  QUICK ACCESS MENU
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_list(request):
    items = QuickAccessMenuItem.objects.all().order_by('order')
    return render(request, 'custom_admin/quick_access/list.html', {'items': items})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_create(request):
    if request.method == 'POST':
        QuickAccessMenuItem.objects.create(
            title_en=request.POST.get('title_en'),
            title_fr=request.POST.get('title_fr', ''),
            icon_name=request.POST.get('icon_name'),
            action_type=request.POST.get('action_type', 'route'),
            action_value=request.POST.get('action_value'),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on',
            has_live_indicator=request.POST.get('has_live_indicator') == 'on',
            badge_text=request.POST.get('badge_text', ''),
        )
        messages.success(request, 'Quick access item created successfully!')
        return redirect('custom_admin:quick_access_list')
    return render(request, 'custom_admin/quick_access/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_edit(request, pk):
    item = get_object_or_404(QuickAccessMenuItem, pk=pk)
    if request.method == 'POST':
        item.title_en = request.POST.get('title_en')
        item.title_fr = request.POST.get('title_fr', '')
        item.icon_name = request.POST.get('icon_name')
        item.action_type = request.POST.get('action_type', 'route')
        item.action_value = request.POST.get('action_value')
        item.order = request.POST.get('order', 0)
        item.is_active = request.POST.get('is_active') == 'on'
        item.has_live_indicator = request.POST.get('has_live_indicator') == 'on'
        item.badge_text = request.POST.get('badge_text', '')
        item.save()
        messages.success(request, 'Quick access item updated successfully!')
        return redirect('custom_admin:quick_access_list')
    return render(request, 'custom_admin/quick_access/form.html', {'item': item, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def quick_access_delete(request, pk):
    item = get_object_or_404(QuickAccessMenuItem, pk=pk)
    item.delete()
    messages.success(request, 'Quick access item deleted successfully!')
    return redirect('custom_admin:quick_access_list')


# ═══════════════════════════════════════════════════════════════
#  PRIORITY AGENDAS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def priority_agendas_list(request):
    agendas = PriorityAgenda.objects.all()
    return render(request, 'custom_admin/priority_agendas/list.html', {'agendas': agendas})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def priority_agenda_create(request):
    if request.method == 'POST':
        from django.utils.text import slugify
        title = request.POST.get('title')
        PriorityAgenda.objects.create(
            title=title,
            title_fr=request.POST.get('title_fr', ''),
            slug=slugify(title),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            overview=request.POST.get('overview', ''),
            overview_fr=request.POST.get('overview_fr', ''),
            icon_name=request.POST.get('icon_name', 'stars'),
            hero_image=request.FILES.get('hero_image'),
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Priority agenda created successfully!')
        return redirect('custom_admin:priority_agendas_list')
    return render(request, 'custom_admin/priority_agendas/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def priority_agenda_edit(request, pk):
    agenda = get_object_or_404(PriorityAgenda, pk=pk)
    if request.method == 'POST':
        from django.utils.text import slugify
        agenda.title = request.POST.get('title')
        agenda.title_fr = request.POST.get('title_fr', '')
        agenda.slug = slugify(agenda.title)
        agenda.description = request.POST.get('description', '')
        agenda.description_fr = request.POST.get('description_fr', '')
        agenda.overview = request.POST.get('overview', '')
        agenda.overview_fr = request.POST.get('overview_fr', '')
        agenda.icon_name = request.POST.get('icon_name', 'stars')
        if request.FILES.get('hero_image'):
            agenda.hero_image = request.FILES.get('hero_image')
        agenda.is_active = request.POST.get('is_active') == 'on'
        agenda.save()
        messages.success(request, 'Priority agenda updated successfully!')
        return redirect('custom_admin:priority_agendas_list')
    return render(request, 'custom_admin/priority_agendas/form.html', {'agenda': agenda, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def priority_agenda_delete(request, pk):
    agenda = get_object_or_404(PriorityAgenda, pk=pk)
    agenda.delete()
    messages.success(request, 'Priority agenda deleted successfully!')
    return redirect('custom_admin:priority_agendas_list')


# ═══════════════════════════════════════════════════════════════
#  GALLERY
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def gallery_list(request):
    albums = GalleryAlbum.objects.all().annotate(actual_photo_count=Count('photos')).order_by('-created_at')
    return render(request, 'custom_admin/gallery/list.html', {'albums': albums})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def gallery_create(request):
    if request.method == 'POST':
        album = GalleryAlbum.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            cover_image=request.FILES.get('cover_image'),
            is_featured=request.POST.get('is_featured') == 'on',
        )
        # Handle multiple photo uploads
        photos = request.FILES.getlist('photos')
        for i, photo in enumerate(photos):
            GalleryPhoto.objects.create(album=album, image=photo, display_order=i)
        album.photo_count = len(photos)
        album.save()
        messages.success(request, f'Album created with {len(photos)} photos!')
        return redirect('custom_admin:gallery_list')
    return render(request, 'custom_admin/gallery/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def gallery_edit(request, pk):
    album = get_object_or_404(GalleryAlbum, pk=pk)
    if request.method == 'POST':
        album.title = request.POST.get('title')
        album.title_fr = request.POST.get('title_fr', '')
        album.description = request.POST.get('description', '')
        album.description_fr = request.POST.get('description_fr', '')
        if request.FILES.get('cover_image'):
            album.cover_image = request.FILES.get('cover_image')
        album.is_featured = request.POST.get('is_featured') == 'on'
        # Handle new photo uploads
        photos = request.FILES.getlist('photos')
        existing_count = album.photos.count()
        for i, photo in enumerate(photos):
            GalleryPhoto.objects.create(album=album, image=photo, display_order=existing_count + i)
        album.photo_count = album.photos.count()
        album.save()
        messages.success(request, 'Album updated successfully!')
        return redirect('custom_admin:gallery_list')
    return render(request, 'custom_admin/gallery/form.html', {'album': album, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def gallery_delete(request, pk):
    album = get_object_or_404(GalleryAlbum, pk=pk)
    album.delete()
    messages.success(request, 'Album deleted successfully!')
    return redirect('custom_admin:gallery_list')


# ═══════════════════════════════════════════════════════════════
#  VIDEOS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def videos_list(request):
    videos = Video.objects.all().order_by('-created_at')
    paginator = Paginator(videos, 20)
    page = request.GET.get('page')
    videos = paginator.get_page(page)
    return render(request, 'custom_admin/videos/list.html', {'videos': videos})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def video_create(request):
    if request.method == 'POST':
        video = Video.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            video_url=request.POST.get('video_url', ''),
            thumbnail=request.FILES.get('thumbnail'),
            duration=request.POST.get('duration', ''),
            category=request.POST.get('category', 'highlight'),
            publish_date=request.POST.get('publish_date') or timezone.now(),
            is_featured=request.POST.get('is_featured') == 'on',
        )
        if request.FILES.get('video_file'):
            video.video_file = request.FILES['video_file']
            video.save()
        messages.success(request, 'Video created successfully!')
        return redirect('custom_admin:videos_list')
    category_choices = Video.CATEGORY_CHOICES
    return render(request, 'custom_admin/videos/form.html', {'action': 'Create', 'category_choices': category_choices})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def video_edit(request, pk):
    video = get_object_or_404(Video, pk=pk)
    if request.method == 'POST':
        video.title = request.POST.get('title')
        video.title_fr = request.POST.get('title_fr', '')
        video.description = request.POST.get('description', '')
        video.description_fr = request.POST.get('description_fr', '')
        video.video_url = request.POST.get('video_url', '')
        if request.FILES.get('video_file'):
            video.video_file = request.FILES['video_file']
        if request.FILES.get('thumbnail'):
            video.thumbnail = request.FILES.get('thumbnail')
        video.duration = request.POST.get('duration', '')
        video.category = request.POST.get('category', 'highlight')
        video.is_featured = request.POST.get('is_featured') == 'on'
        video.save()
        messages.success(request, 'Video updated successfully!')
        return redirect('custom_admin:videos_list')
    category_choices = Video.CATEGORY_CHOICES
    return render(request, 'custom_admin/videos/form.html', {'video': video, 'action': 'Edit', 'category_choices': category_choices})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def video_delete(request, pk):
    video = get_object_or_404(Video, pk=pk)
    video.delete()
    messages.success(request, 'Video deleted successfully!')
    return redirect('custom_admin:videos_list')


# ═══════════════════════════════════════════════════════════════
#  LIVE FEEDS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def live_feeds_list(request):
    feeds = LiveFeed.objects.all().order_by('-created_at')
    return render(request, 'custom_admin/live_feeds/list.html', {'feeds': feeds})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def live_feed_create(request):
    if request.method == 'POST':
        LiveFeed.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            stream_url=request.POST.get('stream_url'),
            thumbnail=request.FILES.get('thumbnail'),
            status=request.POST.get('status', 'upcoming'),
            duration=request.POST.get('duration', ''),
            scheduled_time=request.POST.get('scheduled_time') or None,
        )
        messages.success(request, 'Live feed created successfully!')
        return redirect('custom_admin:live_feeds_list')
    return render(request, 'custom_admin/live_feeds/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def live_feed_edit(request, pk):
    feed = get_object_or_404(LiveFeed, pk=pk)
    if request.method == 'POST':
        feed.title = request.POST.get('title')
        feed.title_fr = request.POST.get('title_fr', '')
        feed.stream_url = request.POST.get('stream_url')
        if request.FILES.get('thumbnail'):
            feed.thumbnail = request.FILES.get('thumbnail')
        feed.status = request.POST.get('status', 'upcoming')
        feed.duration = request.POST.get('duration', '')
        feed.scheduled_time = request.POST.get('scheduled_time') or None
        feed.save()
        messages.success(request, 'Live feed updated successfully!')
        return redirect('custom_admin:live_feeds_list')
    return render(request, 'custom_admin/live_feeds/form.html', {'feed': feed, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def live_feed_delete(request, pk):
    feed = get_object_or_404(LiveFeed, pk=pk)
    feed.delete()
    messages.success(request, 'Live feed deleted successfully!')
    return redirect('custom_admin:live_feeds_list')


# ═══════════════════════════════════════════════════════════════
#  EMBASSIES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def embassies_list(request):
    embassies = EmbassyLocation.objects.all().order_by('country')
    embassy_count = embassies.filter(type='embassy').count()
    consulate_count = embassies.filter(type='consulate').count()
    return render(request, 'custom_admin/embassies/list.html', {
        'embassies': embassies,
        'embassy_count': embassy_count,
        'consulate_count': consulate_count,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def embassy_create(request):
    if request.method == 'POST':
        EmbassyLocation.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            address=request.POST.get('address'),
            city=request.POST.get('city'),
            country=request.POST.get('country'),
            latitude=request.POST.get('latitude', 0),
            longitude=request.POST.get('longitude', 0),
            phone_number=request.POST.get('phone_number', ''),
            email=request.POST.get('email', ''),
            website=request.POST.get('website', ''),
            type=request.POST.get('type', 'embassy'),
        )
        messages.success(request, 'Embassy created successfully!')
        return redirect('custom_admin:embassies_list')
    return render(request, 'custom_admin/embassies/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def embassy_edit(request, pk):
    embassy = get_object_or_404(EmbassyLocation, pk=pk)
    if request.method == 'POST':
        embassy.name = request.POST.get('name')
        embassy.name_fr = request.POST.get('name_fr', '')
        embassy.address = request.POST.get('address')
        embassy.city = request.POST.get('city')
        embassy.country = request.POST.get('country')
        embassy.latitude = request.POST.get('latitude', 0)
        embassy.longitude = request.POST.get('longitude', 0)
        embassy.phone_number = request.POST.get('phone_number', '')
        embassy.email = request.POST.get('email', '')
        embassy.website = request.POST.get('website', '')
        embassy.type = request.POST.get('type', 'embassy')
        embassy.save()
        messages.success(request, 'Embassy updated successfully!')
        return redirect('custom_admin:embassies_list')
    return render(request, 'custom_admin/embassies/form.html', {'embassy': embassy, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def embassy_delete(request, pk):
    embassy = get_object_or_404(EmbassyLocation, pk=pk)
    embassy.delete()
    messages.success(request, 'Embassy deleted successfully!')
    return redirect('custom_admin:embassies_list')


# ═══════════════════════════════════════════════════════════════
#  RESOURCES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def resources_list(request):
    resources = Resource.objects.all().order_by('-created_at')
    paginator = Paginator(resources, 20)
    page = request.GET.get('page')
    resources = paginator.get_page(page)
    return render(request, 'custom_admin/resources/list.html', {'resources': resources})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def resource_create(request):
    if request.method == 'POST':
        Resource.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            category=request.POST.get('category', 'official_documents'),
            file=request.FILES.get('file'),
            file_size=request.POST.get('file_size', ''),
            file_type=request.POST.get('file_type', 'pdf'),
        )
        messages.success(request, 'Resource created successfully!')
        return redirect('custom_admin:resources_list')
    return render(request, 'custom_admin/resources/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def resource_edit(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    if request.method == 'POST':
        resource.title = request.POST.get('title')
        resource.title_fr = request.POST.get('title_fr', '')
        resource.category = request.POST.get('category', 'official_documents')
        if request.FILES.get('file'):
            resource.file = request.FILES.get('file')
        resource.file_size = request.POST.get('file_size', '')
        resource.file_type = request.POST.get('file_type', 'pdf')
        resource.save()
        messages.success(request, 'Resource updated successfully!')
        return redirect('custom_admin:resources_list')
    return render(request, 'custom_admin/resources/form.html', {'resource': resource, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def resource_delete(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    resource.delete()
    messages.success(request, 'Resource deleted successfully!')
    return redirect('custom_admin:resources_list')


# ═══════════════════════════════════════════════════════════════
#  SOCIAL MEDIA LINKS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_list(request):
    links = SocialMediaLink.objects.all().order_by('display_order')
    return render(request, 'custom_admin/social_media/list.html', {'links': links})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_create(request):
    if request.method == 'POST':
        SocialMediaLink.objects.create(
            platform=request.POST.get('platform'),
            display_name=request.POST.get('display_name'),
            display_name_fr=request.POST.get('display_name_fr', ''),
            url=request.POST.get('url'),
            handle=request.POST.get('handle', ''),
            follower_count=request.POST.get('follower_count', ''),
            display_order=request.POST.get('display_order', 0),
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Social media link created successfully!')
        return redirect('custom_admin:social_media_list')
    return render(request, 'custom_admin/social_media/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_edit(request, pk):
    link = get_object_or_404(SocialMediaLink, pk=pk)
    if request.method == 'POST':
        link.platform = request.POST.get('platform')
        link.display_name = request.POST.get('display_name')
        link.display_name_fr = request.POST.get('display_name_fr', '')
        link.url = request.POST.get('url')
        link.handle = request.POST.get('handle', '')
        link.follower_count = request.POST.get('follower_count', '')
        link.display_order = request.POST.get('display_order', 0)
        link.is_active = request.POST.get('is_active') == 'on'
        link.save()
        messages.success(request, 'Social media link updated successfully!')
        return redirect('custom_admin:social_media_list')
    return render(request, 'custom_admin/social_media/form.html', {'link': link, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def social_media_delete(request, pk):
    link = get_object_or_404(SocialMediaLink, pk=pk)
    link.delete()
    messages.success(request, 'Social media link deleted successfully!')
    return redirect('custom_admin:social_media_list')


# ═══════════════════════════════════════════════════════════════
#  WEATHER CITIES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_cities_list(request):
    cities = WeatherCity.objects.all().order_by('order')
    return render(request, 'custom_admin/weather_cities/list.html', {'cities': cities})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_city_create(request):
    if request.method == 'POST':
        WeatherCity.objects.create(
            name=request.POST.get('name'),
            latitude=request.POST.get('latitude', 0),
            longitude=request.POST.get('longitude', 0),
            background_image=request.FILES.get('background_image'),
            order=request.POST.get('order', 0),
            is_default=request.POST.get('is_default') == 'on',
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Weather city created successfully!')
        return redirect('custom_admin:weather_cities_list')
    return render(request, 'custom_admin/weather_cities/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_city_edit(request, pk):
    city = get_object_or_404(WeatherCity, pk=pk)
    if request.method == 'POST':
        city.name = request.POST.get('name')
        city.latitude = request.POST.get('latitude', 0)
        city.longitude = request.POST.get('longitude', 0)
        if request.FILES.get('background_image'):
            city.background_image = request.FILES.get('background_image')
        city.order = request.POST.get('order', 0)
        city.is_default = request.POST.get('is_default') == 'on'
        city.is_active = request.POST.get('is_active') == 'on'
        city.save()
        messages.success(request, 'Weather city updated successfully!')
        return redirect('custom_admin:weather_cities_list')
    return render(request, 'custom_admin/weather_cities/form.html', {'city': city, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def weather_city_delete(request, pk):
    city = get_object_or_404(WeatherCity, pk=pk)
    city.delete()
    messages.success(request, 'Weather city deleted successfully!')
    return redirect('custom_admin:weather_cities_list')


# ═══════════════════════════════════════════════════════════════
#  APP SETTINGS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def app_settings(request):
    settings = AppSettings.load()
    if request.method == 'POST':
        settings.summit_year = request.POST.get('summit_year', '2026')
        settings.summit_theme = request.POST.get('summit_theme', '')
        settings.summit_theme_fr = request.POST.get('summit_theme_fr', '')
        settings.website_url = request.POST.get('website_url', '')
        settings.facebook_url = request.POST.get('facebook_url', '')
        settings.twitter_url = request.POST.get('twitter_url', '')
        settings.instagram_url = request.POST.get('instagram_url', '')
        settings.app_description = request.POST.get('app_description', '')
        settings.app_description_fr = request.POST.get('app_description_fr', '')
        settings.developer_name = request.POST.get('developer_name', '')
        settings.developer_url = request.POST.get('developer_url', '')
        settings.sms_verification_enabled = request.POST.get('sms_verification_enabled') == 'on'
        settings.whatsapp_verification_enabled = request.POST.get('whatsapp_verification_enabled') == 'on'
        settings.live_agent_online = request.POST.get('live_agent_online') == 'on'
        settings.save()
        messages.success(request, 'App settings saved successfully!')
        return redirect('custom_admin:app_settings')
    audit_logs = AuditLogEntry.objects.all()[:20]
    return render(request, 'custom_admin/app_settings/view.html', {'settings': settings, 'audit_logs': audit_logs})


# ═══════════════════════════════════════════════════════════════
#  ANALYTICS
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#  SUPPORT TICKETS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def support_tickets_list(request):
    tickets = SupportTicket.objects.all().select_related('user', 'assigned_to').order_by('-updated_at')

    # Filters
    status_filter = request.GET.get('status')
    if status_filter:
        tickets = tickets.filter(status=status_filter)
    search = request.GET.get('search')
    if search:
        tickets = tickets.filter(
            Q(subject__icontains=search) | Q(user__email__icontains=search) |
            Q(user__first_name__icontains=search)
        )

    total = SupportTicket.objects.count()
    open_count = SupportTicket.objects.filter(status='open').count()
    in_progress_count = SupportTicket.objects.filter(status='in_progress').count()
    resolved_count = SupportTicket.objects.filter(status='resolved').count()

    paginator = Paginator(tickets, 20)
    page = request.GET.get('page')
    tickets_page = paginator.get_page(page)

    return render(request, 'custom_admin/support/list.html', {
        'tickets': tickets_page,
        'total': total,
        'open_count': open_count,
        'in_progress_count': in_progress_count,
        'resolved_count': resolved_count,
        'current_status': status_filter,
        'search': search or '',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def support_ticket_detail(request, pk):
    ticket = get_object_or_404(SupportTicket.objects.select_related('user', 'assigned_to'), pk=pk)
    ticket_messages = ticket.messages.select_related('sender').all()
    return render(request, 'custom_admin/support/detail.html', {
        'ticket': ticket,
        'messages': ticket_messages,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def support_ticket_reply(request, pk):
    ticket = get_object_or_404(SupportTicket, pk=pk)
    message_text = request.POST.get('message', '').strip()

    if not message_text:
        messages.error(request, 'Reply message cannot be empty.')
        return redirect('custom_admin:support_ticket_detail', pk=pk)

    # Create admin reply
    TicketMessage.objects.create(
        ticket=ticket,
        sender=request.user,
        message=message_text,
        is_admin_reply=True,
        is_read=False,
    )

    # Update ticket status
    if ticket.status == 'open':
        ticket.status = 'in_progress'
        ticket.assigned_to = request.user
        ticket.save(update_fields=['status', 'assigned_to'])

    # Send email copy to user
    try:
        from django.core.mail import send_mail
        from django.conf import settings as django_settings
        send_mail(
            subject=f'Re: {ticket.subject} - Support Ticket #{ticket.pk}',
            message=(
                f'Hello {ticket.user.first_name or ticket.user.username},\n\n'
                f'You have a new reply to your support ticket:\n\n'
                f'"{message_text}"\n\n'
                f'Open the Burundi AU app to continue the conversation.\n\n'
                f'Best regards,\n'
                f'Burundi AU Support Team'
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[ticket.user.email],
            fail_silently=True,
        )
    except Exception:
        pass  # Don't block reply if email fails

    # Send push notification to user
    try:
        from config.firebase import initialize_firebase
        initialize_firebase()
        from firebase_admin import messaging

        fcm_token = ticket.user.profile.fcm_token if hasattr(ticket.user, 'profile') else ''
        if fcm_token:
            fcm_message = messaging.Message(
                notification=messaging.Notification(
                    title=f'Support Reply: {ticket.subject}',
                    body=message_text[:100],
                ),
                data={
                    'type': 'support_reply',
                    'ticket_id': str(ticket.pk),
                },
                token=fcm_token,
            )
            messaging.send(fcm_message)
    except Exception:
        pass  # Don't block reply if push fails

    messages.success(request, 'Reply sent successfully! User has been notified.')
    return redirect('custom_admin:support_ticket_detail', pk=pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def support_ticket_update_status(request, pk):
    ticket = get_object_or_404(SupportTicket, pk=pk)
    new_status = request.POST.get('status')
    if new_status not in dict(SupportTicket.STATUS_CHOICES):
        messages.error(request, 'Invalid status.')
        return redirect('custom_admin:support_ticket_detail', pk=pk)

    ticket.status = new_status
    if new_status == 'resolved':
        ticket.resolved_at = timezone.now()

        # Send closing template message asking for rating
        closing_msg = (
            'Your support ticket has been resolved. '
            'We hope we were able to help!\n\n'
            'Please rate your experience to help us improve our service. '
            'Thank you for using Burundi AU Chairmanship support.'
        )
        TicketMessage.objects.create(
            ticket=ticket,
            sender=request.user,
            message=closing_msg,
            is_admin_reply=True,
            is_read=False,
        )

        # Send email with closing template
        try:
            from django.core.mail import send_mail
            from django.conf import settings as django_settings
            send_mail(
                subject=f'Ticket Resolved: {ticket.subject} - #{ticket.pk}',
                message=(
                    f'Hello {ticket.user.first_name or ticket.user.username},\n\n'
                    f'Your support ticket "#{ticket.pk} - {ticket.subject}" has been resolved.\n\n'
                    f'Please open the Burundi AU app to rate your experience.\n\n'
                    f'If you need further help, you can always open a new ticket.\n\n'
                    f'Best regards,\n'
                    f'Burundi AU Support Team'
                ),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=[ticket.user.email],
                fail_silently=True,
            )
        except Exception:
            pass

    ticket.save()
    messages.success(request, f'Ticket status updated to {new_status}.')
    return redirect('custom_admin:support_ticket_detail', pk=pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def analytics_dashboard(request):
    from datetime import timedelta
    from django.db.models.functions import TruncMonth

    # User growth by month
    user_growth = (
        User.objects.filter(date_joined__gte=timezone.now() - timedelta(days=180))
        .annotate(month=TruncMonth('date_joined'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )
    months = [g['month'].strftime('%b %Y') for g in user_growth]
    month_counts = [g['count'] for g in user_growth]

    # Top articles
    top_articles = Article.objects.order_by('-view_count')[:5] if hasattr(Article, 'view_count') else Article.objects.order_by('-created_at')[:5]

    # Top events
    top_events = Event.objects.filter(is_active=True).order_by('-event_date')[:5]

    context = {
        'total_users': User.objects.count(),
        'total_articles': Article.objects.count(),
        'total_events': Event.objects.count(),
        'total_magazines': MagazineEdition.objects.count(),
        'total_resources': Resource.objects.count(),
        'months_json': months,
        'month_counts_json': month_counts,
        'top_articles': top_articles,
        'top_events': top_events,
        'new_users_7d': User.objects.filter(date_joined__gte=timezone.now() - timedelta(days=7)).count(),
        'active_users': User.objects.filter(last_login__gte=timezone.now() - timedelta(days=30)).count(),
    }
    return render(request, 'custom_admin/analytics/dashboard.html', context)
