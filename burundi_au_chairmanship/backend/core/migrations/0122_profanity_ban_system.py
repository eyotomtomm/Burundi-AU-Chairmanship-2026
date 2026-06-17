"""Add profanity strike / comment ban system.

Adds ban-related fields to UserProfile and a new DeviceBan model for
device-level bans that persist across accounts.
"""
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0121_livefeed_likes_and_comments'),
    ]

    operations = [
        # UserProfile — profanity strike fields
        migrations.AddField(
            model_name='userprofile',
            name='profanity_strikes',
            field=models.PositiveIntegerField(default=0, help_text='Number of profanity violations'),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='is_comment_banned',
            field=models.BooleanField(default=False, help_text='Permanently banned from commenting'),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='comment_banned_at',
            field=models.DateTimeField(blank=True, null=True, help_text='When the comment ban was applied'),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='device_id',
            field=models.CharField(blank=True, db_index=True, max_length=255, help_text='Persistent device UUID from client'),
        ),

        # DeviceBan model
        migrations.CreateModel(
            name='DeviceBan',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('device_id', models.CharField(db_index=True, max_length=255, unique=True)),
                ('reason', models.CharField(default='Exceeded profanity strike limit', max_length=255)),
                ('banned_at', models.DateTimeField(auto_now_add=True)),
                ('is_active', models.BooleanField(default=True)),
                ('unbanned_at', models.DateTimeField(blank=True, null=True)),
                ('user', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='device_bans',
                    to=settings.AUTH_USER_MODEL,
                    help_text='The user whose profanity violations triggered this device ban',
                )),
                ('unbanned_by', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='device_unbans',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'ordering': ['-banned_at'],
                'verbose_name': 'Device Ban',
                'verbose_name_plural': 'Device Bans',
            },
        ),
    ]
