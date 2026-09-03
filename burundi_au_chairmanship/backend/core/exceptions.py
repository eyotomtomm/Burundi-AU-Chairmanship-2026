"""DRF exception handler that guarantees error bodies carry ``detail``.

Some views return ``{'error': ...}`` or ``{'message': ...}``; the Flutter
client reads ``detail``. Additive only — existing keys are kept.
"""
from rest_framework.views import exception_handler


def detail_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is not None and isinstance(response.data, dict) and 'detail' not in response.data:
        for key in ('error', 'message', 'non_field_errors'):
            if key in response.data:
                value = response.data[key]
                response.data['detail'] = value[0] if isinstance(value, list) and value else value
                break
    return response
