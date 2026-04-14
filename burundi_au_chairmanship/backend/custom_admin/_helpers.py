"""Shared helpers for custom_admin view modules.

As the custom admin grows we split views.py into multiple files. Anything
that needs to be imported across those files lives here to avoid circular
imports between sibling modules.
"""


def is_staff(user):
    """Auth gate used by every custom_admin view."""
    return user.is_staff or user.is_superuser
