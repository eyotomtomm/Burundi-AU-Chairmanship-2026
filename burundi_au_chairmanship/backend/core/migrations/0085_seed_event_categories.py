from django.db import migrations


def seed_categories(apps, schema_editor):
    EventCategory = apps.get_model('core', 'EventCategory')
    categories = [
        {'name': 'Official Event', 'name_fr': '\u00c9v\u00e9nement officiel', 'icon_name': 'verified', 'color': '#1B5E20', 'order': 1},
        {'name': 'Youth Conference', 'name_fr': 'Conf\u00e9rence jeunesse', 'icon_name': 'groups', 'color': '#1565C0', 'order': 2},
        {'name': 'Webinar', 'name_fr': 'Webinaire', 'icon_name': 'videocam', 'color': '#6A1B9A', 'order': 3},
        {'name': 'Summit', 'name_fr': 'Sommet', 'icon_name': 'flag', 'color': '#BF360C', 'order': 4},
        {'name': 'Workshop', 'name_fr': 'Atelier', 'icon_name': 'construction', 'color': '#E65100', 'order': 5},
        {'name': 'Gala / Reception', 'name_fr': 'Gala / R\u00e9ception', 'icon_name': 'celebration', 'color': '#AD1457', 'order': 6},
        {'name': 'Press Conference', 'name_fr': 'Conf\u00e9rence de presse', 'icon_name': 'mic', 'color': '#00695C', 'order': 7},
        {'name': 'Cultural Event', 'name_fr': '\u00c9v\u00e9nement culturel', 'icon_name': 'palette', 'color': '#FF6F00', 'order': 8},
        {'name': 'Sports', 'name_fr': 'Sports', 'icon_name': 'sports', 'color': '#2E7D32', 'order': 9},
        {'name': 'Other', 'name_fr': 'Autre', 'icon_name': 'event', 'color': '#455A64', 'order': 99},
    ]
    for cat in categories:
        EventCategory.objects.get_or_create(name=cat['name'], defaults=cat)


class Migration(migrations.Migration):
    dependencies = [
        ('core', '0084_add_event_category'),
    ]
    operations = [
        migrations.RunPython(seed_categories, migrations.RunPython.noop),
    ]
