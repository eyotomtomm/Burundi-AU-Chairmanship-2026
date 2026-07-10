from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0152_phrasebookentry'),
    ]

    operations = [
        migrations.AddField(
            model_name='appsettings',
            name='developer_role',
            field=models.CharField(blank=True, default='Lead Developer', help_text='Developer role/title shown in About dialog', max_length=100),
        ),
        migrations.AddField(
            model_name='appsettings',
            name='app_ownership_text',
            field=models.CharField(blank=True, default='Property of Burundi Embassy in Addis Ababa', help_text='Ownership line shown in About dialog', max_length=300),
        ),
    ]
