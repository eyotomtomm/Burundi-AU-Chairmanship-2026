from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0156_disable_live_feeds'),
        ('core', '0155_youthdialogueevent_scanner_title'),
    ]

    operations = [
        migrations.AlterField(
            model_name='emergencycontact',
            name='action_type',
            field=models.CharField(
                choices=[
                    ('call', 'Phone Call'),
                    ('whatsapp', 'WhatsApp'),
                    ('sms', 'SMS'),
                    ('email', 'Email'),
                    ('url', 'Website / Link'),
                    ('route', 'In-App Route'),
                ],
                default='call',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='sos_title',
            field=models.CharField(
                blank=True,
                default='Emergency / SOS',
                help_text='SOS screen title (English)',
                max_length=100,
            ),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='sos_title_fr',
            field=models.CharField(
                blank=True,
                default='Urgence / SOS',
                help_text='SOS screen title (French)',
                max_length=100,
            ),
        ),
    ]
