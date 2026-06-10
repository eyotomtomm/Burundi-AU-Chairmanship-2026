from django.db import migrations, models
import django.db.models.deletion
import core.models


def seed_default_form_fields(apps, schema_editor):
    """Seed 11 default form fields matching the current hardcoded apply screen."""
    YouthDialogueSettings = apps.get_model('core', 'YouthDialogueSettings')
    YouthDialogueFormField = apps.get_model('core', 'YouthDialogueFormField')

    settings, _ = YouthDialogueSettings.objects.get_or_create(pk=1)

    defaults = [
        {'order': 0,  'field_type': 'select',      'field_label': 'Title',           'field_name': 'title',          'is_required': False,
         'options': ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'H.E.', 'Ambassador', 'Honorable', 'Other']},
        {'order': 1,  'field_type': 'text',         'field_label': 'First Name',      'field_name': 'first_name',     'is_required': True},
        {'order': 2,  'field_type': 'text',         'field_label': 'Last Name',       'field_name': 'last_name',      'is_required': True},
        {'order': 3,  'field_type': 'date',         'field_label': 'Date of Birth',   'field_name': 'date_of_birth',  'is_required': False},
        {'order': 4,  'field_type': 'select',       'field_label': 'Gender',          'field_name': 'gender',         'is_required': False,
         'options': ['Male', 'Female']},
        {'order': 5,  'field_type': 'email',        'field_label': 'Email',           'field_name': 'email',          'is_required': True},
        {'order': 6,  'field_type': 'phone',        'field_label': 'Phone Number',    'field_name': 'phone_number',   'is_required': False},
        {'order': 7,  'field_type': 'nationality',  'field_label': 'Nationality',     'field_name': 'nationality',    'is_required': True},
        {'order': 8,  'field_type': 'text',         'field_label': 'Organization',    'field_name': 'organization',   'is_required': False},
        {'order': 9,  'field_type': 'text',         'field_label': 'Position / Role', 'field_name': 'position',       'is_required': False},
        {'order': 10, 'field_type': 'textarea',     'field_label': 'Motivation',      'field_name': 'motivation',     'is_required': True,
         'help_text': 'Why do you want to participate?'},
    ]

    for field_def in defaults:
        YouthDialogueFormField.objects.create(
            settings=settings,
            field_type=field_def['field_type'],
            field_label=field_def['field_label'],
            field_name=field_def['field_name'],
            is_required=field_def['is_required'],
            order=field_def['order'],
            options=field_def.get('options', []),
            help_text=field_def.get('help_text', ''),
            is_active=True,
        )


def reverse_seed(apps, schema_editor):
    YouthDialogueFormField = apps.get_model('core', 'YouthDialogueFormField')
    YouthDialogueFormField.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0105_appsettings_store_urls'),
    ]

    operations = [
        # Add visibility fields to YouthDialogueSettings
        migrations.AddField(
            model_name='youthdialoguesettings',
            name='is_visible',
            field=models.BooleanField(default=True, help_text='Show Youth Dialogue in Quick Access grid'),
        ),
        migrations.AddField(
            model_name='youthdialoguesettings',
            name='quick_access_icon',
            field=models.ImageField(blank=True, help_text='Custom icon for Quick Access grid',
                                    upload_to='youth_dialogue/', validators=[core.models.validate_image_file]),
        ),
        migrations.AddField(
            model_name='youthdialoguesettings',
            name='quick_access_title_en',
            field=models.CharField(blank=True, default='Youth Dialogue', help_text='Quick Access button title (EN)', max_length=50),
        ),
        migrations.AddField(
            model_name='youthdialoguesettings',
            name='quick_access_title_fr',
            field=models.CharField(blank=True, default='Dialogue Jeunesse', help_text='Quick Access button title (FR)', max_length=50),
        ),

        # Create YouthDialogueFormField model
        migrations.CreateModel(
            name='YouthDialogueFormField',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('field_type', models.CharField(choices=[
                    ('text', 'Text Input'), ('email', 'Email'), ('phone', 'Phone Number'),
                    ('textarea', 'Text Area'), ('number', 'Number'), ('date', 'Date'),
                    ('time', 'Time'), ('file', 'File Upload'), ('image', 'Image Upload'),
                    ('select', 'Dropdown Select'), ('radio', 'Radio Buttons'),
                    ('checkbox', 'Single Checkbox'), ('multi_checkbox', 'Multiple Checkboxes'),
                    ('country', 'Country Selector'), ('nationality', 'Nationality'),
                    ('passport', 'Passport Number'), ('url', 'URL / Website'),
                ], max_length=20)),
                ('field_label', models.CharField(help_text='Label shown to user', max_length=200)),
                ('field_label_fr', models.CharField(blank=True, max_length=200)),
                ('field_name', models.CharField(help_text='Internal field name (e.g., "first_name", "motivation")', max_length=100)),
                ('placeholder', models.CharField(blank=True, max_length=200)),
                ('placeholder_fr', models.CharField(blank=True, max_length=200)),
                ('is_required', models.BooleanField(default=False)),
                ('is_active', models.BooleanField(default=True, help_text='Show/hide this field')),
                ('options', models.JSONField(blank=True, default=list, help_text='For select/radio/multi_checkbox: ["Option 1", "Option 2"]')),
                ('validation_regex', models.CharField(blank=True, help_text='Optional regex for validation', max_length=500)),
                ('help_text', models.CharField(blank=True, max_length=300)),
                ('help_text_fr', models.CharField(blank=True, max_length=300)),
                ('max_length', models.IntegerField(blank=True, null=True)),
                ('min_length', models.IntegerField(blank=True, null=True)),
                ('order', models.IntegerField(default=0)),
                ('settings', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='form_fields',
                    to='core.youthdialoguesettings',
                )),
            ],
            options={
                'ordering': ['order'],
                'verbose_name': 'Youth Dialogue Form Field',
                'verbose_name_plural': 'Youth Dialogue Form Fields',
            },
        ),

        # Seed default form fields
        migrations.RunPython(seed_default_form_fields, reverse_seed),
    ]
