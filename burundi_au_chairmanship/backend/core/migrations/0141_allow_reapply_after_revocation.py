from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0140_about_page_editable'),
    ]

    operations = [
        # Drop old unconditional unique constraint
        migrations.RemoveConstraint(
            model_name='youthdialogueapplication',
            name='unique_user_event_application',
        ),
        # Add new conditional constraint: only non-revoked applications
        migrations.AddConstraint(
            model_name='youthdialogueapplication',
            constraint=models.UniqueConstraint(
                fields=['user', 'event'],
                condition=models.Q(is_revoked=False),
                name='unique_user_event_application',
            ),
        ),
    ]
