"""
Image optimization utilities for the B4Africa app.

Generates multiple size variants (thumbnail, medium, large) from uploaded images
and converts them to WebP format for better compression and faster loading.
"""
import logging
import os
from io import BytesIO
from pathlib import Path

from PIL import Image
from django.conf import settings
from django.core.files.base import ContentFile

logger = logging.getLogger(__name__)

# Size presets: (name_suffix, max_width)
IMAGE_SIZES = {
    'thumb': 300,
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


def generate_thumbnails_on_disk(image_path):
    """
    Generate multi-size WebP thumbnails from a saved image file on disk.

    Given the full filesystem path to an image, creates three variants:
        - <name>_thumb.webp   (300px wide,  quality 70)
        - <name>_medium.webp  (600px wide,  quality 80)
        - <name>_large.webp   (1200px wide, quality 85)

    The variant files are saved in the same directory as the original.

    Args:
        image_path: Absolute filesystem path to the source image.

    Returns:
        dict: Mapping of size name to the absolute path of the generated file.
              e.g. {'thumb': '/media/articles/photo_thumb.webp', ...}
              Returns empty dict if processing fails.
    """
    source = Path(image_path)
    if not source.exists():
        logger.warning("generate_thumbnails_on_disk: source not found: %s", image_path)
        return {}

    generated = {}
    try:
        img = Image.open(source)

        # Convert RGBA/P to RGB for WebP compatibility
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        # Strip the existing size suffix if re-processing (e.g. photo_thumb -> photo)
        stem = source.stem
        for suffix in ('_thumb', '_medium', '_large'):
            if stem.endswith(suffix):
                stem = stem[: -len(suffix)]
                break

        for size_name, max_width in IMAGE_SIZES.items():
            if img.width <= max_width:
                resized = img.copy()
            else:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                resized = img.resize((max_width, new_height), Image.LANCZOS)

            quality = 70 if size_name == 'thumb' else 80 if size_name == 'medium' else 85
            out_path = source.parent / f"{stem}_{size_name}.webp"
            resized.save(str(out_path), format='WEBP', quality=quality, optimize=True)
            generated[size_name] = str(out_path)
            logger.info("Generated %s variant: %s", size_name, out_path)

    except Exception:
        logger.exception("Failed to generate thumbnails for %s", image_path)

    return generated


def generate_thumbnails_to_storage(image_field):
    """
    Generate multi-size WebP thumbnails and save them via the field's
    storage backend (works with S3 / DigitalOcean Spaces).

    Downloads the original image into memory, resizes it, and uploads
    the variants back to the same storage in the same directory.

    Args:
        image_field: A Django FieldFile / ImageFieldFile with a valid name.

    Returns:
        dict: Mapping of size name to the storage name of the generated file.
              e.g. {'thumb': 'hero_slides/photo_thumb.webp', ...}
              Returns empty dict if processing fails.
    """
    if not image_field or not image_field.name:
        return {}

    generated = {}
    try:
        image_field.open('rb')
        img = Image.open(image_field)
        img.load()  # force read before closing the file handle
        image_field.close()

        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        base, _ext = os.path.splitext(image_field.name)
        for suffix in ('_thumb', '_medium', '_large'):
            if base.endswith(suffix):
                base = base[: -len(suffix)]
                break

        storage = image_field.storage

        for size_name, max_width in IMAGE_SIZES.items():
            if img.width <= max_width:
                resized = img.copy()
            else:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                resized = img.resize((max_width, new_height), Image.LANCZOS)

            quality = 70 if size_name == 'thumb' else 80 if size_name == 'medium' else 85
            buf = BytesIO()
            resized.save(buf, format='WEBP', quality=quality, optimize=True)
            buf.seek(0)

            variant_name = f"{base}_{size_name}.webp"
            # Overwrite if the variant already exists.
            if storage.exists(variant_name):
                storage.delete(variant_name)
            saved_name = storage.save(variant_name, ContentFile(buf.read()))
            generated[size_name] = saved_name
            logger.info("Generated %s variant (remote): %s", size_name, saved_name)

    except Exception:
        logger.exception(
            "Failed to generate remote thumbnails for %s",
            image_field.name if image_field else '(none)',
        )

    return generated


def get_variant_url(image_field, size_name):
    """
    Return the URL of a size variant for a given ImageField value.

    Constructs the URL by replacing the file extension with ``_<size>webp``.
    Does *not* check whether the file exists on disk (the frontend should
    fall back to the original URL if a variant 404s).

    Args:
        image_field: A Django FieldFile / ImageFieldFile instance (e.g. ``instance.image``).
        size_name: One of ``'thumb'``, ``'medium'``, or ``'large'``.

    Returns:
        str or None: The variant URL, or ``None`` if no image is set.
    """
    if not image_field or not image_field.name:
        return None

    base, _ext = os.path.splitext(image_field.name)
    # Strip an existing size suffix to avoid stacking (e.g. photo_thumb_thumb)
    for suffix in ('_thumb', '_medium', '_large'):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break

    variant_name = f"{base}_{size_name}.webp"

    # Build the full URL the same way Django does
    try:
        return image_field.storage.url(variant_name)
    except Exception:
        return None
