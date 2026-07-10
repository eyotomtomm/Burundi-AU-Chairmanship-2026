from django.db import migrations


def disable_live_feeds(apps, schema_editor):
    AppSettings = apps.get_model('core', 'AppSettings')
    AppSettings.objects.update(live_feeds_enabled=False)


def enable_live_feeds(apps, schema_editor):
    AppSettings = apps.get_model('core', 'AppSettings')
    AppSettings.objects.update(live_feeds_enabled=True)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0155_userprofile_verification_fields'),
    ]

    operations = [
        migrations.RunPython(disable_live_feeds, enable_live_feeds),
    ]
