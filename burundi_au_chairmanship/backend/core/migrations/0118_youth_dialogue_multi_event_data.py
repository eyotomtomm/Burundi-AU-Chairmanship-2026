"""
Migration B: Data backfill for Youth Dialogue multi-event.

- Set existing pk=1 event: is_active=True, slug='youth-dialogue-2026'
- Link all existing applications to the pk=1 event
- Link all existing activity logs to the pk=1 event
"""
from django.db import migrations


def backfill_event_data(apps, schema_editor):
    YouthDialogueEvent = apps.get_model('core', 'YouthDialogueEvent')
    YouthDialogueApplication = apps.get_model('core', 'YouthDialogueApplication')
    YouthDialogueActivityLog = apps.get_model('core', 'YouthDialogueActivityLog')

    # Activate the existing singleton record and give it a slug
    event = YouthDialogueEvent.objects.filter(pk=1).first()
    if event:
        event.is_active = True
        event.slug = 'youth-dialogue-2026'
        event.save(update_fields=['is_active', 'slug'])

        # Link orphaned applications
        YouthDialogueApplication.objects.filter(event__isnull=True).update(event=event)

        # Link orphaned activity logs
        YouthDialogueActivityLog.objects.filter(event__isnull=True).update(event=event)


def reverse_backfill(apps, schema_editor):
    # Nothing destructive needed on reverse — nullable FKs will just be cleared
    YouthDialogueApplication = apps.get_model('core', 'YouthDialogueApplication')
    YouthDialogueActivityLog = apps.get_model('core', 'YouthDialogueActivityLog')
    YouthDialogueApplication.objects.all().update(event=None)
    YouthDialogueActivityLog.objects.all().update(event=None)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0117_youth_dialogue_multi_event_schema'),
    ]

    operations = [
        migrations.RunPython(backfill_event_data, reverse_backfill),
    ]
