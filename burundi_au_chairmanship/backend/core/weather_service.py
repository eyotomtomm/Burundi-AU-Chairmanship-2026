"""
WeatherAPI.com proxy service with Django cache.

Fetches current weather + 3-day forecast from WeatherAPI.com and caches
results to avoid redundant upstream calls. API key stays server-side.
"""

import json
import logging
import urllib.request
import urllib.error
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)

WEATHERAPI_BASE = 'https://api.weatherapi.com/v1'


def get_weather_for_city(lat, lon):
    """
    Fetch current weather + 3-day forecast for the given coordinates.
    Results are cached for CACHE_TTL_WEATHER seconds (default 30 min),
    keyed by rounded lat/lon (2 decimal places ≈ 1.1 km precision).
    """
    # Round to 2 decimals for cache deduplication
    rlat = round(float(lat), 2)
    rlon = round(float(lon), 2)
    cache_key = f'weather:city:{rlat}:{rlon}'

    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    api_key = getattr(settings, 'WEATHERAPI_KEY', '')
    if not api_key:
        logger.error('WEATHERAPI_KEY not configured')
        return None

    url = (
        f'{WEATHERAPI_BASE}/forecast.json'
        f'?key={api_key}&q={rlat},{rlon}&days=3&aqi=no&alerts=no'
    )

    try:
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
        logger.warning('WeatherAPI.com fetch failed for %s,%s: %s', rlat, rlon, e)
        return None

    normalized = _normalize_weather(data)
    ttl = getattr(settings, 'CACHE_TTL_WEATHER', 1800)
    cache.set(cache_key, normalized, ttl)
    return normalized


def search_cities(query):
    """
    Search for cities by name via WeatherAPI.com autocomplete.
    Results cached for 1 hour.
    """
    query = str(query).strip()
    cache_key = f'weather:search:{query.lower()}'

    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    api_key = getattr(settings, 'WEATHERAPI_KEY', '')
    if not api_key:
        logger.error('WEATHERAPI_KEY not configured')
        return None

    url = (
        f'{WEATHERAPI_BASE}/search.json'
        f'?key={api_key}&q={urllib.request.quote(query)}'
    )

    try:
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
        logger.warning('WeatherAPI.com search failed for %r: %s', query, e)
        return None

    results = [
        {
            'name': item.get('name', ''),
            'region': item.get('region', ''),
            'country': item.get('country', ''),
            'lat': item.get('lat'),
            'lon': item.get('lon'),
        }
        for item in (data if isinstance(data, list) else [])
    ]

    cache.set(cache_key, results, 3600)  # 1 hour
    return results


def _normalize_weather(data):
    """
    Transform WeatherAPI.com response into a stable frontend-friendly format.
    """
    current = data.get('current', {})
    condition = current.get('condition', {})
    forecast_data = data.get('forecast', {}).get('forecastday', [])

    # Sunrise/sunset from today's forecast
    today_astro = forecast_data[0].get('astro', {}) if forecast_data else {}

    result = {
        'current': {
            'temp_c': current.get('temp_c', 0),
            'feels_like_c': current.get('feelslike_c', 0),
            'humidity': current.get('humidity', 0),
            'wind_kph': current.get('wind_kph', 0),
            'uv': current.get('uv', 0),
            'weather_code': condition.get('code', 0),
            'condition_text': condition.get('text', ''),
            'condition_icon': condition.get('icon', ''),
            'is_day': current.get('is_day', 1),
        },
        'sunrise': today_astro.get('sunrise', ''),
        'sunset': today_astro.get('sunset', ''),
        'forecast': [],
    }

    for day in forecast_data:
        day_data = day.get('day', {})
        day_condition = day_data.get('condition', {})
        result['forecast'].append({
            'date': day.get('date', ''),
            'max_temp_c': day_data.get('maxtemp_c', 0),
            'min_temp_c': day_data.get('mintemp_c', 0),
            'weather_code': day_condition.get('code', 0),
            'condition_text': day_condition.get('text', ''),
            'condition_icon': day_condition.get('icon', ''),
            'chance_of_rain': day_data.get('daily_chance_of_rain', 0),
        })

    return result
