from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0143_alter_aboutfeature_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueapplication',
            name='allow_reapply',
            field=models.BooleanField(default=True, help_text='If False, user is permanently revoked and cannot re-apply.'),
        ),
    ]
