"""
Migration: Add recurring scheduling, open tracking, and DeviceToken model.

Changes:
- Notification: is_scheduled, schedule_type, schedule_day, schedule_time,
  last_scheduled_send, opened_count fields + new index
- DeviceToken: new model for multi-account FCM token management
"""

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import core.validators


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0074_remove_podcast_model'),
    ]

    operations = [
        # --- Notification scheduling fields ---
        migrations.AddField(
            model_name='notification',
            name='is_scheduled',
            field=models.BooleanField(
                default=False,
                help_text='Enable recurring schedule for this notification',
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='schedule_type',
            field=models.CharField(
                blank=True,
                choices=[('once', 'One-time'), ('daily', 'Daily'), ('weekly', 'Weekly')],
                default='once',
                help_text='How often to repeat this notification',
                max_length=10,
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='schedule_day',
            field=models.IntegerField(
                blank=True,
                help_text='Day of week for weekly schedule (0=Monday, 6=Sunday)',
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='schedule_time',
            field=models.TimeField(
                blank=True,
                help_text='Time of day to send the scheduled notification (HH:MM)',
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='notification',
            name='last_scheduled_send',
            field=models.DateTimeField(
                blank=True,
                help_text='Last time this recurring notification was sent',
                null=True,
            ),
        ),
        # --- Open tracking ---
        migrations.AddField(
            model_name='notification',
            name='opened_count',
            field=models.IntegerField(
                default=0,
                help_text='Number of times users opened/tapped this notification',
            ),
        ),
        # --- Additional index for scheduled notifications ---
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(
                fields=['is_scheduled', 'schedule_type'],
                name='core_notifi_is_sche_idx',
            ),
        ),
        # --- DeviceToken model ---
        migrations.CreateModel(
            name='DeviceToken',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('token', models.CharField(
                    db_index=True,
                    help_text='FCM registration token',
                    max_length=255,
                    validators=[core.validators.validate_fcm_token],
                )),
                ('is_active', models.BooleanField(
                    default=True,
                    help_text='Deactivated on logout, reactivated on login',
                )),
                ('device_type', models.CharField(
                    blank=True,
                    help_text='e.g. iPhone 15, Samsung Galaxy S24',
                    max_length=50,
                )),
                ('device_os', models.CharField(
                    blank=True,
                    help_text='e.g. iOS 17.4, Android 14',
                    max_length=50,
                )),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='device_tokens',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'verbose_name': 'Device Token',
                'verbose_name_plural': 'Device Tokens',
                'unique_together': {('user', 'token')},
            },
        ),
        migrations.AddIndex(
            model_name='devicetoken',
            index=models.Index(
                fields=['is_active', 'token'],
                name='core_device_is_acti_idx',
            ),
        ),
    ]
