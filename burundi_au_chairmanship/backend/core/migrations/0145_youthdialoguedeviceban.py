import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('core', '0144_youthdialogueapplication_allow_reapply'),
    ]

    operations = [
        migrations.AddField(
            model_name='youthdialogueapplication',
            name='device_id',
            field=models.CharField(blank=True, db_index=True, default='', help_text='Device UUID captured at application time', max_length=255),
            preserve_default=False,
        ),
        migrations.CreateModel(
            name='YouthDialogueDeviceBan',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('device_id', models.CharField(db_index=True, max_length=255, unique=True)),
                ('reason', models.CharField(default='Permanently revoked from Continental Dialogue', max_length=255)),
                ('banned_at', models.DateTimeField(auto_now_add=True)),
                ('is_active', models.BooleanField(default=True)),
                ('unbanned_at', models.DateTimeField(blank=True, null=True)),
                ('unbanned_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='yd_device_unbans', to=settings.AUTH_USER_MODEL)),
                ('user', models.ForeignKey(blank=True, help_text='The user whose revocation triggered this device ban', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='yd_device_bans', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'YD Device Ban',
                'verbose_name_plural': 'YD Device Bans',
                'ordering': ['-banned_at'],
            },
        ),
    ]
