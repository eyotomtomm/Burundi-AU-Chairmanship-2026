"""Data migration to seed default onboarding steps in EN + FR."""

from django.db import migrations


def create_onboarding_steps(apps, schema_editor):
    OnboardingStep = apps.get_model('core', 'OnboardingStep')

    # Only seed if no steps exist
    if OnboardingStep.objects.exists():
        return

    steps = [
        {
            'title': 'Welcome to Be 4 Africa',
            'title_fr': 'Bienvenue au Pr\u00e9sidence de l\'UA du Burundi',
            'description': 'Stay connected with Burundi\'s Be 4 Africa 2026-2027. Get the latest news, events, and exclusive content right at your fingertips.',
            'description_fr': 'Restez connect\u00e9 avec la Pr\u00e9sidence de l\'Union Africaine du Burundi 2026-2027. Acc\u00e9dez aux derni\u00e8res nouvelles, \u00e9v\u00e9nements et contenus exclusifs.',
            'icon_name': 'waving_hand',
            'order': 1,
        },
        {
            'title': 'Explore Features',
            'title_fr': 'Explorer les fonctionnalit\u00e9s',
            'description': 'Browse articles, watch live feeds, view the photo gallery, read magazines, and discover Burundi\'s priority agendas for the Be 4 Africa.',
            'description_fr': 'Parcourez les articles, regardez les diffusions en direct, consultez la galerie photo, lisez les magazines et d\u00e9couvrez les agendas prioritaires du Burundi.',
            'icon_name': 'explore',
            'order': 2,
        },
        {
            'title': 'Stay Connected',
            'title_fr': 'Restez connect\u00e9',
            'description': 'Register for events, join live broadcasts, and participate in polls and discussions with the AU community.',
            'description_fr': 'Inscrivez-vous aux \u00e9v\u00e9nements, rejoignez les diffusions en direct et participez aux sondages et discussions avec la communaut\u00e9 de l\'UA.',
            'icon_name': 'group',
            'order': 3,
        },
        {
            'title': 'Get Verified',
            'title_fr': 'Obtenez la v\u00e9rification',
            'description': 'Complete your profile and apply for verification to unlock exclusive features and get your verified badge.',
            'description_fr': 'Compl\u00e9tez votre profil et demandez la v\u00e9rification pour d\u00e9bloquer des fonctionnalit\u00e9s exclusives et obtenir votre badge v\u00e9rifi\u00e9.',
            'icon_name': 'verified',
            'order': 4,
        },
        {
            'title': 'Stay Informed',
            'title_fr': 'Restez inform\u00e9',
            'description': 'Enable push notifications to never miss important updates, event reminders, and breaking news about the Be 4 Africa.',
            'description_fr': 'Activez les notifications push pour ne jamais manquer les mises \u00e0 jour importantes, les rappels d\'\u00e9v\u00e9nements et les nouvelles de la Pr\u00e9sidence de l\'UA.',
            'icon_name': 'notifications_active',
            'order': 5,
        },
    ]

    for step_data in steps:
        OnboardingStep.objects.create(**step_data, is_active=True)


def remove_onboarding_steps(apps, schema_editor):
    OnboardingStep = apps.get_model('core', 'OnboardingStep')
    OnboardingStep.objects.filter(
        icon_name__in=['waving_hand', 'explore', 'group', 'verified', 'notifications_active']
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0064_abtest_announcementbanner_apprelease_and_more'),
    ]

    operations = [
        migrations.RunPython(create_onboarding_steps, remove_onboarding_steps),
    ]
