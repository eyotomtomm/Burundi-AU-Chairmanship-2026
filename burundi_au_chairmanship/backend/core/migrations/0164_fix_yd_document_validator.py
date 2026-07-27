# Fix YouthDialogueDocument file validator to accept both images and documents.
# The previous validator (validate_document_file) rejected JPG/PNG uploads,
# causing photo uploads to fail at the model level.

import core.validators
from django.db import migrations, models
import core.models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0163_seed_burundi_emergency_contacts'),
    ]

    operations = [
        migrations.AlterField(
            model_name='youthdialoguedocument',
            name='file',
            field=models.FileField(
                storage=core.models._private_storage,
                upload_to='youth_dialogue/documents/',
                validators=[core.validators.validate_document_or_image_file],
            ),
        ),
    ]
