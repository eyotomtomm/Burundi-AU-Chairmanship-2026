from django.db import migrations

# The identities admins can post to the Explore feed as.
OFFICIAL_ACCOUNTS = [
    {
        'username': 'b4africa',
        'first_name': 'B4Africa',
        'organization': 'Be 4 Africa',
        'role': 'Official account',
    },
    {
        'username': 'burundi_embassy_addis',
        'first_name': 'Burundi Embassy in Addis Ababa',
        'organization': 'Embassy of the Republic of Burundi to Ethiopia',
        'role': 'Official account',
    },
]


def create_official_accounts(apps, schema_editor):
    User = apps.get_model('auth', 'User')
    UserProfile = apps.get_model('core', 'UserProfile')
    for spec in OFFICIAL_ACCOUNTS:
        user, _ = User.objects.get_or_create(
            username=spec['username'],
            defaults={
                'first_name': spec['first_name'],
                'is_active': True,
                # No usable password — these are posted-as identities, not logins.
                'password': '!',
            },
        )
        UserProfile.objects.update_or_create(
            user=user,
            defaults={
                'organization': spec['organization'],
                'role': spec['role'],
                'is_verified': True,
                'badge_type': 'BLUE',
                'is_government_official': True,
                'is_email_verified': True,
                # The model's save() normally stamps this; historical models
                # in a migration don't run it.
                'reference_id': f'B{user.pk:06d}',
            },
        )


def remove_official_accounts(apps, schema_editor):
    User = apps.get_model('auth', 'User')
    User.objects.filter(
        username__in=[s['username'] for s in OFFICIAL_ACCOUNTS]
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0175_userprofile_bio'),
    ]

    operations = [
        migrations.RunPython(create_official_accounts, remove_official_accounts),
    ]
