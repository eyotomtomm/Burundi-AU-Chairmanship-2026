"""Seed comprehensive Burundi emergency contacts and update SOS title."""

from django.db import migrations


BURUNDI_CONTACTS = [
    # --- Police ---
    {
        'name_en': 'Police Emergency',
        'name_fr': 'Police Secours',
        'description_en': 'Police Nationale du Burundi (PNB) — Emergency line',
        'description_fr': 'Police Nationale du Burundi (PNB) — Numéro d\'urgence',
        'icon_name': 'local_police',
        'category': 'police',
        'action_type': 'call',
        'contact_value': '117',
        'color': '#1565C0',
        'order': 1,
    },
    {
        'name_en': 'PNB Headquarters',
        'name_fr': 'QG de la PNB',
        'description_en': 'Police Nationale du Burundi — General enquiries',
        'description_fr': 'Police Nationale du Burundi — Renseignements généraux',
        'icon_name': 'local_police',
        'category': 'police',
        'action_type': 'call',
        'contact_value': '+257 22 22 21 33',
        'color': '#1565C0',
        'order': 2,
    },
    # --- Fire ---
    {
        'name_en': 'Fire Department',
        'name_fr': 'Pompiers',
        'description_en': 'Sapeurs-Pompiers du Burundi — Fire & Rescue',
        'description_fr': 'Sapeurs-Pompiers du Burundi — Secours incendie',
        'icon_name': 'local_fire_department',
        'category': 'fire',
        'action_type': 'call',
        'contact_value': '118',
        'color': '#E53935',
        'order': 3,
    },
    # --- Medical ---
    {
        'name_en': 'SAMU Ambulance',
        'name_fr': 'SAMU Ambulance',
        'description_en': 'Service d\'Aide Médicale Urgente — Emergency ambulance',
        'description_fr': 'Service d\'Aide Médicale Urgente — Ambulance d\'urgence',
        'icon_name': 'medical_services',
        'category': 'medical',
        'action_type': 'call',
        'contact_value': '115',
        'color': '#2E7D32',
        'order': 4,
    },
    {
        'name_en': 'Red Cross Burundi',
        'name_fr': 'Croix-Rouge du Burundi',
        'description_en': 'First aid, disaster relief & blood bank',
        'description_fr': 'Premiers secours, aide humanitaire & banque de sang',
        'icon_name': 'health_and_safety',
        'category': 'medical',
        'action_type': 'call',
        'contact_value': '+257 22 21 63 05',
        'color': '#C62828',
        'order': 5,
    },
    {
        'name_en': 'CHUK Hospital',
        'name_fr': 'Hôpital CHUK',
        'description_en': 'Centre Hospitalo-Universitaire de Kamenge — Main referral hospital',
        'description_fr': 'Centre Hospitalo-Universitaire de Kamenge — Hôpital de référence',
        'icon_name': 'local_hospital',
        'category': 'medical',
        'action_type': 'call',
        'contact_value': '+257 22 23 49 55',
        'color': '#2E7D32',
        'order': 6,
    },
    {
        'name_en': 'Prince Régent Charles Hospital',
        'name_fr': 'Hôpital Prince Régent Charles',
        'description_en': 'HPRC Bujumbura — General & emergency care',
        'description_fr': 'HPRC Bujumbura — Soins généraux & urgences',
        'icon_name': 'local_hospital',
        'category': 'medical',
        'action_type': 'call',
        'contact_value': '+257 22 21 51 10',
        'color': '#2E7D32',
        'order': 7,
    },
    {
        'name_en': 'Military Hospital Kamenge',
        'name_fr': 'Hôpital Militaire de Kamenge',
        'description_en': 'Hôpital Militaire — Open to civilians for emergencies',
        'description_fr': 'Hôpital Militaire — Ouvert aux civils en cas d\'urgence',
        'icon_name': 'local_hospital',
        'category': 'medical',
        'action_type': 'call',
        'contact_value': '+257 22 23 24 40',
        'color': '#2E7D32',
        'order': 8,
    },
    # --- Other (Civil Protection & Utilities) ---
    {
        'name_en': 'Civil Protection',
        'name_fr': 'Protection Civile',
        'description_en': 'Natural disasters, floods & civil emergencies',
        'description_fr': 'Catastrophes naturelles, inondations & urgences civiles',
        'icon_name': 'shield',
        'category': 'other',
        'action_type': 'call',
        'contact_value': '+257 22 22 28 19',
        'color': '#E65100',
        'order': 9,
    },
    {
        'name_en': 'REGIDESO (Water & Electricity)',
        'name_fr': 'REGIDESO (Eau & Électricité)',
        'description_en': 'Report power outages, water cuts & utility emergencies',
        'description_fr': 'Signaler coupures d\'eau, d\'électricité & urgences',
        'icon_name': 'emergency',
        'category': 'other',
        'action_type': 'call',
        'contact_value': '+257 22 22 34 52',
        'color': '#F57F17',
        'order': 10,
    },
    # --- Support ---
    {
        'name_en': 'App Support',
        'name_fr': 'Assistance',
        'description_en': 'In-app support & live agent chat',
        'description_fr': 'Assistance dans l\'app & chat en direct',
        'icon_name': 'support_agent',
        'category': 'support',
        'action_type': 'route',
        'contact_value': '/support',
        'color': '#6A1B9A',
        'order': 11,
    },
]


def seed_burundi_contacts(apps, schema_editor):
    EmergencyContact = apps.get_model('core', 'EmergencyContact')
    AppSettings = apps.get_model('core', 'AppSettings')

    # Remove old generic contacts that are being replaced
    EmergencyContact.objects.filter(
        name_en__in=['Police', 'Fire Department', 'Ambulance', 'App Support']
    ).delete()

    # Insert Burundi-specific contacts
    for ec in BURUNDI_CONTACTS:
        EmergencyContact.objects.update_or_create(
            name_en=ec['name_en'],
            defaults=ec,
        )

    # Update SOS titles to mention Burundi
    AppSettings.objects.all().update(
        sos_title='SOS Burundi',
        sos_title_fr='SOS Burundi',
    )


def reverse_seed(apps, schema_editor):
    EmergencyContact = apps.get_model('core', 'EmergencyContact')
    names = [c['name_en'] for c in BURUNDI_CONTACTS]
    EmergencyContact.objects.filter(name_en__in=names).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0162_expand_phrasebook_entries'),
    ]

    operations = [
        migrations.RunPython(seed_burundi_contacts, reverse_seed),
    ]
