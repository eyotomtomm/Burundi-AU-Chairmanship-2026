"""Add ProfanityStrikeLog model for tracking profanity violations.

Logs every profanity violation (flagged content, matched word, content type)
so admins can review what was written before deciding to unban a user.
"""
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0122_profanity_ban_system'),
    ]

    operations = [
        migrations.CreateModel(
            name='ProfanityStrikeLog',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('device_id', models.CharField(blank=True, db_index=True, max_length=255)),
                ('user_agent', models.TextField(blank=True, help_text='Browser/app user-agent string at time of violation')),
                ('flagged_content', models.TextField(help_text='Full text the user attempted to post')),
                ('matched_word', models.CharField(blank=True, max_length=100)),
                ('content_type', models.CharField(
                    blank=True, max_length=30,
                    choices=[
                        ('article_comment', 'Article Comment'),
                        ('discussion_comment', 'Discussion Comment'),
                        ('event_comment', 'Event Comment'),
                        ('gallery_comment', 'Gallery Comment'),
                        ('livefeed_comment', 'Live Feed Comment'),
                        ('magazine_comment', 'Magazine Comment'),
                        ('video_comment', 'Video Comment'),
                    ],
                )),
                ('strike_number', models.PositiveIntegerField()),
                ('resulted_in_ban', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='profanity_strike_logs',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
