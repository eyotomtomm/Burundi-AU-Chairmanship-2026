"""
Image optimization utilities for the B4Africa app.

Generates multiple size variants (thumbnail, medium, large) from uploaded images
and converts them to WebP format for better compression and faster loading.
"""
import os
from io import BytesIO
from PIL import Image
from django.core.files.base import ContentFile


# Size presets: (name_suffix, max_width)
IMAGE_SIZES = {
    'thumb': 200,
    'medium': 600,
    'large': 1200,
}


def optimize_image(image_field, max_width=1200, quality=85):
    """
    Optimize a single image by resizing and converting to WebP.
    Modifies the image field in-place (call before save).

    Args:
        image_field: Django ImageField instance
        max_width: Maximum width in pixels
        quality: WebP quality (1-100)
    """
    if not image_field:
        return

    try:
        img = Image.open(image_field)

        # Convert RGBA to RGB for WebP compatibility
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        # Only resize if larger than max_width
        if img.width > max_width:
            ratio = max_width / img.width
            new_height = int(img.height * ratio)
            img = img.resize((max_width, new_height), Image.LANCZOS)

        # Save as WebP
        buffer = BytesIO()
        img.save(buffer, format='WEBP', quality=quality, optimize=True)
        buffer.seek(0)

        # Replace the original file with optimized version
        original_name = os.path.splitext(image_field.name)[0]
        new_name = f"{original_name}.webp"
        image_field.save(new_name, ContentFile(buffer.read()), save=False)

    except Exception:
        # If optimization fails, keep the original image
        pass


def generate_image_variants(image_field, upload_to=''):
    """
    Generate thumbnail, medium, and large variants from an image.
    Returns a dict of {size_name: ContentFile} pairs.

    Args:
        image_field: Django ImageField instance
        upload_to: Upload directory prefix

    Returns:
        dict: {'thumb': ContentFile, 'medium': ContentFile, 'large': ContentFile}
    """
    if not image_field:
        return {}

    variants = {}
    try:
        img = Image.open(image_field)

        # Convert RGBA to RGB
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        original_name = os.path.splitext(os.path.basename(image_field.name))[0]

        for size_name, max_width in IMAGE_SIZES.items():
            if img.width <= max_width:
                # Image already smaller than target — still convert to WebP
                resized = img.copy()
            else:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                resized = img.resize((max_width, new_height), Image.LANCZOS)

            buffer = BytesIO()
            quality = 70 if size_name == 'thumb' else 80 if size_name == 'medium' else 85
            resized.save(buffer, format='WEBP', quality=quality, optimize=True)
            buffer.seek(0)

            filename = f"{original_name}_{size_name}.webp"
            if upload_to:
                filename = f"{upload_to}/{filename}"

            variants[size_name] = ContentFile(buffer.read(), name=filename)

    except Exception:
        pass

    return variants
