from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0059_video_gallery_likes'),
    ]

    operations = [
        # Add denormalized like_count to Article
        migrations.AddField(
            model_name='article',
            name='like_count',
            field=models.PositiveIntegerField(default=0),
        ),

        # Create UserSession model for analytics/geolocation tracking
        migrations.CreateModel(
            name='UserSession',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('ip_address', models.GenericIPAddressField()),
                ('country_code', models.CharField(blank=True, db_index=True, max_length=5)),
                ('country_name', models.CharField(blank=True, max_length=100)),
                ('city', models.CharField(blank=True, max_length=100)),
                ('user_nationality', models.CharField(blank=True, db_index=True, help_text='Snapshot from UserProfile at session time', max_length=5)),
                ('device_type', models.CharField(blank=True, max_length=50)),
                ('device_os', models.CharField(blank=True, max_length=50)),
                ('app_version', models.CharField(blank=True, max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='sessions', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'User Session',
                'verbose_name_plural': 'User Sessions',
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='usersession',
            index=models.Index(fields=['country_code', 'created_at'], name='core_userse_country_idx'),
        ),
        migrations.AddIndex(
            model_name='usersession',
            index=models.Index(fields=['user_nationality', 'created_at'], name='core_userse_user_na_idx'),
        ),
    ]
