from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0129_add_is_usher_to_userprofile'),
    ]

    operations = [
        migrations.CreateModel(
            name='YouthDialogueRole',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(help_text='Role name in English (e.g. Participant)', max_length=100)),
                ('name_fr', models.CharField(blank=True, help_text='Role name in French', max_length=100)),
                ('color', models.CharField(default='#4CAF50', help_text='Hex colour for credential card header', max_length=7)),
                ('order', models.IntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
                ('event', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='roles', to='core.youthdialogueevent')),
            ],
            options={
                'verbose_name': 'Youth Dialogue Role',
                'verbose_name_plural': 'Youth Dialogue Roles',
                'ordering': ['order'],
                'unique_together': {('event', 'name')},
            },
        ),
    ]
