from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0154_add_notification_source'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='organization',
            field=models.CharField(blank=True, help_text='Organization or company the user belongs to', max_length=200),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='role',
            field=models.CharField(blank=True, help_text='Role or position within their organization', max_length=200),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='social_media_url',
            field=models.URLField(blank=True, help_text='Primary social media profile URL (LinkedIn, X, etc.)', max_length=500),
        ),
    ]
