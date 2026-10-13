from django.db import migrations

# Peace & Security is the chairmanship's second priority and A-RISE the third.
ORDER = {'water-sanitation': 1, 'peace-security': 2, 'arise-initiative': 3}


def set_order(apps, schema_editor):
    PriorityAgenda = apps.get_model('core', 'PriorityAgenda')
    for slug, n in ORDER.items():
        PriorityAgenda.objects.filter(slug=slug).update(display_order=n)


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0188_eventregistration_meeting_id_and_more'),
    ]

    operations = [
        migrations.RunPython(set_order, migrations.RunPython.noop),
    ]
