from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0146_appsettings_qr_scanner_titles'),
    ]

    operations = [
        migrations.CreateModel(
            name='YouthDialogueSideEvent',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(help_text='Side event name in English', max_length=200)),
                ('name_fr', models.CharField(blank=True, help_text='Side event name in French', max_length=200)),
                ('description', models.TextField(blank=True, help_text='Brief description in English')),
                ('description_fr', models.TextField(blank=True, help_text='Brief description in French')),
                ('event_date', models.DateField(blank=True, help_text='Date of the side event', null=True)),
                ('event_time', models.TimeField(blank=True, help_text='Start time of the side event', null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('order', models.IntegerField(default=0)),
                ('event', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='side_events', to='core.youthdialogueevent')),
            ],
            options={
                'verbose_name': 'Continental Dialogue Side Event',
                'verbose_name_plural': 'Continental Dialogue Side Events',
                'ordering': ['order'],
            },
        ),
        migrations.AddField(
            model_name='youthdialogueapplication',
            name='selected_side_events',
            field=models.ManyToManyField(blank=True, related_name='applications', to='core.youthdialoguesideevent'),
        ),
    ]
