from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0110_use_private_storage_for_user_uploads'),
    ]

    operations = [
        migrations.AddField(
            model_name='eventsubmission',
            name='proxy_email_verified',
            field=models.BooleanField(
                default=False,
                help_text='Whether the proxy email owner has acknowledged the registration',
            ),
        ),
    ]
