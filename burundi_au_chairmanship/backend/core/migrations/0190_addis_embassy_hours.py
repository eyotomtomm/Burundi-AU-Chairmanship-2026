from django.db import migrations


def set_hours(apps, schema_editor):
    EmbassyLocation = apps.get_model('core', 'EmbassyLocation')
    EmbassyLocation.objects.filter(city__icontains='addis').update(opening_hours='Mon-Fri: 9:00 AM - 5:00 PM')


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0189_priority_agenda_order'),
    ]

    operations = [
        migrations.RunPython(set_hours, migrations.RunPython.noop),
    ]
