import io
import logging
from datetime import timedelta
from django.db.models import Count, Sum, Q
from django.db.models.functions import TruncMonth
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from .models import (
    Article, MagazineEdition, Video, GalleryAlbum,
    UserProfile, UserSession, AuditLogEntry,
)
from django.contrib.auth.models import User

logger = logging.getLogger(__name__)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def analytics_overview(request):
    """High-level summary: users + content engagement."""
    now = timezone.now()
    total_users = User.objects.count()
    new_7d = User.objects.filter(date_joined__gte=now - timedelta(days=7)).count()
    new_30d = User.objects.filter(date_joined__gte=now - timedelta(days=30)).count()
    active_7d = User.objects.filter(last_login__gte=now - timedelta(days=7)).count()
    active_30d = User.objects.filter(last_login__gte=now - timedelta(days=30)).count()
    active_today = User.objects.filter(last_login__date=now.date()).count()

    content = {
        'articles': {
            'count': Article.objects.count(),
            'total_views': Article.objects.aggregate(s=Sum('view_count'))['s'] or 0,
            'total_likes': Article.objects.aggregate(s=Sum('like_count'))['s'] or 0,
        },
        'magazines': {
            'count': MagazineEdition.objects.count(),
            'total_views': MagazineEdition.objects.aggregate(s=Sum('view_count'))['s'] or 0,
            'total_likes': MagazineEdition.objects.aggregate(s=Sum('like_count'))['s'] or 0,
        },
        'videos': {
            'count': Video.objects.count(),
            'total_views': Video.objects.aggregate(s=Sum('view_count'))['s'] or 0,
            'total_likes': Video.objects.aggregate(s=Sum('like_count'))['s'] or 0,
        },
        'albums': {
            'count': GalleryAlbum.objects.count(),
            'total_views': GalleryAlbum.objects.aggregate(s=Sum('view_count'))['s'] or 0,
            'total_likes': GalleryAlbum.objects.aggregate(s=Sum('like_count'))['s'] or 0,
        },
    }

    return Response({
        'users': {
            'total': total_users,
            'new_7d': new_7d,
            'new_30d': new_30d,
            'active_7d': active_7d,
            'active_30d': active_30d,
            'active_today': active_today,
        },
        'content': content,
    })


@api_view(['GET'])
@permission_classes([IsAdminUser])
def analytics_user_growth(request):
    """Monthly user growth data."""
    months = int(request.GET.get('months', 12))
    months = min(months, 36)  # Cap at 3 years

    since = timezone.now() - timedelta(days=months * 30)
    growth = (
        User.objects.filter(date_joined__gte=since)
        .annotate(month=TruncMonth('date_joined'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )

    data = [
        {'month': g['month'].strftime('%Y-%m'), 'label': g['month'].strftime('%b %Y'), 'count': g['count']}
        for g in growth
    ]

    return Response({'growth': data})


@api_view(['GET'])
@permission_classes([IsAdminUser])
def analytics_countries(request):
    """Country breakdown by nationality and IP geolocation."""
    # By nationality (from UserProfile)
    nationality_data = (
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:20]
    )

    # By IP geolocation (from UserSession)
    ip_country_data = (
        UserSession.objects.exclude(country_code='')
        .values('country_code', 'country_name')
        .annotate(session_count=Count('id'))
        .order_by('-session_count')[:20]
    )

    return Response({
        'by_nationality': list(nationality_data),
        'by_ip_geolocation': list(ip_country_data),
    })


@api_view(['GET'])
@permission_classes([IsAdminUser])
def analytics_content_engagement(request):
    """Top content by type."""
    top_articles = list(
        Article.objects.order_by('-view_count')[:5]
        .values('id', 'title', 'view_count', 'like_count')
    )
    top_magazines = list(
        MagazineEdition.objects.order_by('-view_count')[:5]
        .values('id', 'title', 'view_count', 'like_count')
    )
    top_videos = list(
        Video.objects.order_by('-view_count')[:5]
        .values('id', 'title', 'view_count', 'like_count')
    )

    return Response({
        'top_articles': top_articles,
        'top_magazines': top_magazines,
        'top_videos': top_videos,
    })


@api_view(['GET'])
@permission_classes([IsAdminUser])
def analytics_export_pdf(request):
    """Generate and download PDF analytics report."""
    report_type = request.GET.get('report_type', 'marketing')
    month_str = request.GET.get('month', '')

    if report_type not in ('marketing', 'technical', 'diplomacy'):
        return Response(
            {'detail': 'Invalid report_type. Choose: marketing, technical, diplomacy'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        pdf_bytes = generate_analytics_pdf(report_type, month_str, request.user)
    except Exception as e:
        logger.exception('PDF export failed')
        return Response({'detail': f'Export failed: {e}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # Log the export
    AuditLogEntry.objects.create(
        user=request.user,
        action='EXPORT',
        entity_type='AnalyticsReport',
        entity_label=f'{report_type.title()} report ({month_str or "current"})',
        status='success',
    )

    response = HttpResponse(pdf_bytes, content_type='application/pdf')
    filename = f'burundi_au_{report_type}_report_{month_str or "current"}.pdf'
    response['Content-Disposition'] = f'attachment; filename="{filename}"'
    return response


def generate_analytics_pdf(report_type, month_str, user):
    """Generate an A4 PDF report using ReportLab."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=20*mm, rightMargin=20*mm, topMargin=20*mm, bottomMargin=20*mm)
    elements = []

    styles = getSampleStyleSheet()
    burundi_green = colors.HexColor('#1EB53A')
    au_gold = colors.HexColor('#745B17')

    title_style = ParagraphStyle(
        'ReportTitle', parent=styles['Title'],
        textColor=burundi_green, fontSize=22, spaceAfter=6,
    )
    subtitle_style = ParagraphStyle(
        'ReportSubtitle', parent=styles['Normal'],
        textColor=au_gold, fontSize=12, spaceAfter=12,
    )
    section_style = ParagraphStyle(
        'SectionHeader', parent=styles['Heading2'],
        textColor=burundi_green, fontSize=14, spaceBefore=16, spaceAfter=8,
    )

    now = timezone.now()
    report_names = {
        'marketing': 'Marketing & Engagement Report',
        'technical': 'Technical Analytics Report',
        'diplomacy': 'Diplomacy & Geographic Report',
    }

    # --- Title ---
    elements.append(Paragraph('Burundi AU Chairmanship 2026', title_style))
    elements.append(Paragraph(report_names[report_type], subtitle_style))
    elements.append(Paragraph(f'Generated: {now.strftime("%B %d, %Y at %H:%M")}', styles['Normal']))
    elements.append(Spacer(1, 12))

    # --- User Stats Table (all reports) ---
    elements.append(Paragraph('User Statistics', section_style))
    total_users = User.objects.count()
    new_7d = User.objects.filter(date_joined__gte=now - timedelta(days=7)).count()
    new_30d = User.objects.filter(date_joined__gte=now - timedelta(days=30)).count()
    active_30d = User.objects.filter(last_login__gte=now - timedelta(days=30)).count()

    user_table_data = [
        ['Metric', 'Value'],
        ['Total Users', str(total_users)],
        ['New Users (7 days)', str(new_7d)],
        ['New Users (30 days)', str(new_30d)],
        ['Active Users (30 days)', str(active_30d)],
    ]
    user_table = Table(user_table_data, colWidths=[120*mm, 40*mm])
    user_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), burundi_green),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('ALIGN', (1, 0), (1, -1), 'CENTER'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ]))
    elements.append(user_table)
    elements.append(Spacer(1, 12))

    # --- Content Engagement Table (all reports) ---
    elements.append(Paragraph('Content Engagement', section_style))
    content_data = [
        ['Content Type', 'Count', 'Views', 'Likes'],
        ['Articles', str(Article.objects.count()),
         str(Article.objects.aggregate(s=Sum('view_count'))['s'] or 0),
         str(Article.objects.aggregate(s=Sum('like_count'))['s'] or 0)],
        ['Magazines', str(MagazineEdition.objects.count()),
         str(MagazineEdition.objects.aggregate(s=Sum('view_count'))['s'] or 0),
         str(MagazineEdition.objects.aggregate(s=Sum('like_count'))['s'] or 0)],
        ['Videos', str(Video.objects.count()),
         str(Video.objects.aggregate(s=Sum('view_count'))['s'] or 0),
         str(Video.objects.aggregate(s=Sum('like_count'))['s'] or 0)],
        ['Gallery Albums', str(GalleryAlbum.objects.count()),
         str(GalleryAlbum.objects.aggregate(s=Sum('view_count'))['s'] or 0),
         str(GalleryAlbum.objects.aggregate(s=Sum('like_count'))['s'] or 0)],
    ]
    content_table = Table(content_data, colWidths=[55*mm, 30*mm, 35*mm, 35*mm])
    content_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), au_gold),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('ALIGN', (1, 0), (-1, -1), 'CENTER'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ]))
    elements.append(content_table)
    elements.append(Spacer(1, 12))

    # --- Report-specific sections ---
    if report_type == 'marketing':
        _add_marketing_section(elements, section_style, styles, burundi_green, au_gold, now)
    elif report_type == 'technical':
        _add_technical_section(elements, section_style, styles, burundi_green, au_gold, now)
    elif report_type == 'diplomacy':
        _add_diplomacy_section(elements, section_style, styles, burundi_green, au_gold, now)

    doc.build(elements)
    return buffer.getvalue()


def _add_marketing_section(elements, section_style, styles, burundi_green, au_gold, now):
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import Table, TableStyle, Paragraph, Spacer

    # Top Articles
    elements.append(Paragraph('Top Articles by Views', section_style))
    top_articles = Article.objects.order_by('-view_count')[:10]
    if top_articles:
        data = [['#', 'Title', 'Views', 'Likes']]
        for i, a in enumerate(top_articles, 1):
            data.append([str(i), a.title[:50], str(a.view_count), str(a.like_count)])
        t = Table(data, colWidths=[10*mm, 95*mm, 25*mm, 25*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), burundi_green),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('ALIGN', (0, 0), (0, -1), 'CENTER'),
            ('ALIGN', (2, 0), (-1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
        ]))
        elements.append(t)

    # User Growth Trend
    elements.append(Spacer(1, 12))
    elements.append(Paragraph('Monthly User Growth (Last 12 Months)', section_style))
    from django.db.models.functions import TruncMonth
    since = now - timedelta(days=365)
    growth = (
        User.objects.filter(date_joined__gte=since)
        .annotate(month=TruncMonth('date_joined'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )
    if growth:
        data = [['Month', 'New Users']]
        for g in growth:
            data.append([g['month'].strftime('%b %Y'), str(g['count'])])
        t = Table(data, colWidths=[80*mm, 40*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), au_gold),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ]))
        elements.append(t)


def _add_technical_section(elements, section_style, styles, burundi_green, au_gold, now):
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import Table, TableStyle, Paragraph, Spacer

    # Device OS Distribution
    elements.append(Paragraph('Device OS Distribution', section_style))
    os_data = (
        UserProfile.objects.exclude(device_os='')
        .values('device_os')
        .annotate(count=Count('id'))
        .order_by('-count')[:15]
    )
    if os_data:
        data = [['Operating System', 'Users']]
        for d in os_data:
            data.append([d['device_os'], str(d['count'])])
        t = Table(data, colWidths=[100*mm, 40*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), burundi_green),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
        ]))
        elements.append(t)

    # App Version Distribution
    elements.append(Spacer(1, 12))
    elements.append(Paragraph('App Version Distribution', section_style))
    version_data = (
        UserProfile.objects.exclude(app_version='')
        .values('app_version')
        .annotate(count=Count('id'))
        .order_by('-count')[:10]
    )
    if version_data:
        data = [['App Version', 'Users']]
        for d in version_data:
            data.append([d['app_version'], str(d['count'])])
        t = Table(data, colWidths=[100*mm, 40*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), au_gold),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ]))
        elements.append(t)

    # Session statistics
    elements.append(Spacer(1, 12))
    elements.append(Paragraph('Session Statistics (Last 30 Days)', section_style))
    thirty_days_ago = now - timedelta(days=30)
    total_sessions = UserSession.objects.filter(created_at__gte=thirty_days_ago).count()
    unique_ips = UserSession.objects.filter(created_at__gte=thirty_days_ago).values('ip_address').distinct().count()
    elements.append(Paragraph(f'Total sessions: {total_sessions}', styles['Normal']))
    elements.append(Paragraph(f'Unique IPs: {unique_ips}', styles['Normal']))


def _add_diplomacy_section(elements, section_style, styles, burundi_green, au_gold, now):
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import Table, TableStyle, Paragraph, Spacer

    # Country breakdown by nationality
    elements.append(Paragraph('Users by Nationality', section_style))
    nat_data = (
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:20]
    )
    if nat_data:
        data = [['Country Code', 'Users']]
        for d in nat_data:
            data.append([d['nationality'], str(d['count'])])
        t = Table(data, colWidths=[80*mm, 40*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), burundi_green),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
        ]))
        elements.append(t)

    # Geographic session distribution (by IP)
    elements.append(Spacer(1, 12))
    elements.append(Paragraph('Session Distribution by IP Geolocation', section_style))
    ip_data = (
        UserSession.objects.exclude(country_code='')
        .values('country_code', 'country_name')
        .annotate(session_count=Count('id'))
        .order_by('-session_count')[:20]
    )
    if ip_data:
        data = [['Country', 'Sessions']]
        for d in ip_data:
            data.append([d['country_name'] or d['country_code'], str(d['session_count'])])
        t = Table(data, colWidths=[100*mm, 40*mm])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), au_gold),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
        ]))
        elements.append(t)
