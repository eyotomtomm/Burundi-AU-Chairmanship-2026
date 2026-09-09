import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../models/api_models.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  static const _prefsKey = 'custom_weather_cities';

  final List<_CityWeather> _cities = [];
  List<WeatherCity> _defaultCities = []; // Loaded from backend
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadCitiesAndFetch();
  }

  Future<void> _loadCitiesAndFetch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Fetch default cities from backend API
      final response = await ApiService().get('weather-cities/');
      if (response != null && response is List) {
        _defaultCities = response.map((json) => WeatherCity.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load weather cities from API: $e');
      // Keep _defaultCities empty, fallback below will handle it
    }

    // Fallback: if backend returned no cities, use hardcoded defaults
    if (_defaultCities.isEmpty) {
      _defaultCities = [
        WeatherCity(id: 0, name: 'Bujumbura', latitude: -3.3614, longitude: 29.3599, order: 0, isDefault: true),
        WeatherCity(id: 0, name: 'Addis Ababa', latitude: 9.0192, longitude: 38.7525, order: 1, isDefault: true),
        WeatherCity(id: 0, name: 'Nairobi', latitude: -1.2921, longitude: 36.8219, order: 2, isDefault: true),
      ];
    }

    // Always start with cities from backend (or fallback)
    _cities.clear();
    for (final d in _defaultCities) {
      _cities.add(_CityWeather(
        name: d.name,
        lat: d.latitude,
        lon: d.longitude,
        cityId: d.id > 0 ? d.id : null,
        backgroundImageUrl: (d.backgroundImage != null && d.backgroundImage!.isNotEmpty) ? d.backgroundImage : null,
      ));
    }

    // Load custom cities from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        final List<dynamic> list = jsonDecode(json);
        for (final item in list) {
          _cities.add(_CityWeather(
            name: item['name'] as String,
            lat: (item['lat'] as num).toDouble(),
            lon: (item['lon'] as num).toDouble(),
          ));
        }
      } catch (_) {
        // Ignore corrupt data
      }
    }

    await _fetchWeather();
  }

  Future<void> _saveCustomCities() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = _cities.skip(_defaultCities.length).map((c) => {
      'name': c.name,
      'lat': c.lat,
      'lon': c.lon,
    }).toList();
    await prefs.setString(_prefsKey, jsonEncode(custom));
  }

  bool _isDefaultCity(int index) => index < _defaultCities.length;

  /// Apply normalized weather API response to a city object.
  void _applyWeatherData(_CityWeather city, Map<String, dynamic> data) {
    city.fetchFailed = false;
    final current = data['current'] as Map<String, dynamic>? ?? {};
    city.currentTemp = (current['temp_c'] as num?)?.toDouble() ?? 0;
    city.feelsLike = (current['feels_like_c'] as num?)?.toDouble() ?? 0;
    city.humidity = (current['humidity'] as num?)?.toInt() ?? 0;
    city.windSpeed = (current['wind_kph'] as num?)?.toDouble() ?? 0;
    city.uvIndex = (current['uv'] as num?)?.toDouble() ?? 0;
    city.weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
    city.conditionText = (current['condition_text'] as String?) ?? '';
    city.conditionIcon = (current['condition_icon'] as String?) ?? '';

    city.sunrise = (data['sunrise'] as String?) ?? '';
    city.sunset = (data['sunset'] as String?) ?? '';

    final forecastList = data['forecast'] as List<dynamic>? ?? [];
    city.forecast = forecastList.map((f) {
      final fm = f as Map<String, dynamic>;
      return _DayForecast(
        date: (fm['date'] as String?) ?? '',
        maxTemp: (fm['max_temp_c'] as num?)?.toDouble() ?? 0,
        minTemp: (fm['min_temp_c'] as num?)?.toDouble() ?? 0,
        weatherCode: (fm['weather_code'] as num?)?.toInt() ?? 0,
        conditionText: (fm['condition_text'] as String?) ?? '',
        chanceOfRain: (fm['chance_of_rain'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    // Fetch all cities in parallel; each city records its own failure.
    await Future.wait(_cities.map((city) async {
      try {
        Map<String, dynamic>? data;
        if (city.cityId != null) {
          data = await ApiService().getWeatherForCity(city.cityId!);
        } else {
          data = await ApiService().getWeatherByCoordinates(city.lat, city.lon);
        }
        if (data != null) {
          _applyWeatherData(city, data);
        } else {
          city.fetchFailed = true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Weather fetch failed for ${city.name}: $e');
        city.fetchFailed = true;
      }
    }));
    final failCount = _cities.where((c) => c.fetchFailed).length;
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = failCount == _cities.length && _cities.isNotEmpty;
        if (!_hasError) _lastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _fetchWeatherForCity(_CityWeather city) async {
    try {
      final data = await ApiService().getWeatherByCoordinates(city.lat, city.lon);
      if (data != null) {
        _applyWeatherData(city, data);
      } else {
        city.fetchFailed = true;
      }
    } catch (_) {
      city.fetchFailed = true;
    }
    if (mounted) setState(() {});
  }

  void _showAddCityDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddCityDialog(
        onCitySelected: (name, lat, lon) async {
          final city = _CityWeather(name: name, lat: lat, lon: lon);
          setState(() => _cities.add(city));
          await _saveCustomCities();
          await _fetchWeatherForCity(city);
        },
      ),
    );
  }

  void _showRemoveCityDialog(int index) {
    final city = _cities[index];
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.translate('wx_remove_city')),
        content: Text(
            '${l10n.translate('wx_remove_city_prefix')} ${city.name} ${l10n.translate('wx_remove_city_suffix')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burundiRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _cities.removeAt(index));
              _saveCustomCities();
            },
            child: Text(l10n.translate('remove')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('weather')),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.translate('wx_add_city'),
              onPressed: _showAddCityDialog,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green))
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 56, color: Ds.muted(context)),
                        const SizedBox(height: 16),
                        Text(l10n.translate('wx_could_not_load'),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Ds.ink(context))),
                        const SizedBox(height: 8),
                        Text(l10n.translate('error_loading_subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Ds.body(context))),
                        const SizedBox(height: 20),
                        DsOutlineButton(l10n.translate('retry'),
                            radius: Ds.rPill, onTap: _loadCitiesAndFetch),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Ds.green,
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _fetchWeather();
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      for (var i = 0; i < _cities.length; i++)
                        _isDefaultCity(i)
                            ? _buildCityCard(_cities[i])
                            : GestureDetector(
                                onLongPress: () => _showRemoveCityDialog(i),
                                child: _buildCityCard(_cities[i]),
                              ),
                      if (_lastUpdated != null)
                        DsFootnote('${l10n.translate('sup_updated')} ${_formatTime(_lastUpdated!)}', center: true),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCityCard(_CityWeather city) {
    final l10n = AppLocalizations.of(context);
    final advisory = _getRainAdvisory(city, false);
    final hi = city.forecast.isNotEmpty ? city.forecast.first.maxTemp : city.currentTemp;
    final lo = city.forecast.isNotEmpty ? city.forecast.first.minTemp : city.currentTemp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green hero: the comp's signature weather card.
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: Ds.green,
            borderRadius: BorderRadius.circular(Ds.rSheet),
            boxShadow: [
              BoxShadow(
                color: Ds.green.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(city.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          _lastUpdated == null ? '' : _formatTime(_lastUpdated!),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                  Icon(_getWeatherIcon(city.weatherCode), size: 44, color: Ds.gold),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    city.fetchFailed ? '--°' : '${city.currentTemp.toStringAsFixed(0)}°',
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.1,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_getWeatherDescription(city.weatherCode, city.conditionText)}\n${l10n.translate('wx_high')} ${hi.toStringAsFixed(0)}° · ${l10n.translate('wx_low')} ${lo.toStringAsFixed(0)}°',
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _heroChip(Icons.water_drop_rounded, '${city.humidity}%'),
                  const SizedBox(width: 10),
                  _heroChip(Icons.air_rounded, '${city.windSpeed.toStringAsFixed(0)} km/h'),
                  const SizedBox(width: 10),
                  _heroChip(Icons.wb_twilight_rounded, _formatSunTime(city.sunset)),
                ],
              ),
            ],
          ),
        ),

        if (city.forecast.isNotEmpty)
          DsTileGroup(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              for (final day in city.forecast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_formatDayAbbrev(day.date),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Ds.ink(context))),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(_getWeatherIcon(day.weatherCode),
                            size: 20, color: Ds.green),
                      ),
                      Text(
                        '${day.maxTemp.toStringAsFixed(0)}° / ${day.minTemp.toStringAsFixed(0)}°',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Ds.ink(context)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

        DsFootnote(advisory.text),
      ],
    );
  }

  /// Translucent stat pill inside the green hero card.
  Widget _heroChip(IconData icon, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Ds.rTile),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
        ),
      );

  /// WeatherAPI.com rain condition codes:
  /// 1063-1201: rain/drizzle/freezing rain variants
  /// 1240-1252: rain showers
  /// 1273+: thunderstorm with rain
  bool _isRainyCode(int code) {
    return (code >= 1063 && code <= 1201) ||
        (code >= 1240 && code <= 1252) ||
        code >= 1273;
  }

  ({IconData icon, Color color, Color bgColor, String text}) _getRainAdvisory(_CityWeather city, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final currentRain = _isRainyCode(city.weatherCode);
    final forecastRain = city.forecast.any((d) => _isRainyCode(d.weatherCode));
    // Use the highest chance_of_rain from the forecast
    final maxChance = city.forecast.isEmpty
        ? 0
        : city.forecast.map((d) => d.chanceOfRain).reduce((a, b) => a > b ? a : b);

    if (currentRain) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.burundiRed,
        bgColor: AppColors.burundiRed.withValues(alpha: isDark ? 0.12 : 0.08),
        text: l10n.translate('wx_rain_now'),
      );
    }
    if (forecastRain || maxChance >= 50) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.08),
        text: maxChance > 0
            ? '$maxChance% ${l10n.translate('wx_rain_chance')}'
            : l10n.translate('wx_rain_expected'),
      );
    }
    return (
      icon: Icons.wb_sunny_rounded,
      color: AppColors.burundiGreen,
      bgColor: AppColors.burundiGreen.withValues(alpha: isDark ? 0.1 : 0.06),
      text: l10n.translate('wx_no_rain'),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Parse WeatherAPI.com sun time format ("06:15 AM" or "06:30 PM")
  /// into 24-hour display ("06:15" / "18:30").
  String _formatSunTime(String timeStr) {
    if (timeStr.isEmpty) return '--:--';
    try {
      // WeatherAPI.com format: "06:15 AM" or "06:30 PM"
      final upper = timeStr.trim().toUpperCase();
      final isPM = upper.endsWith('PM');
      final isAM = upper.endsWith('AM');
      if (isPM || isAM) {
        final timePart = upper.replaceAll(RegExp(r'\s*(AM|PM)\s*$'), '').trim();
        final parts = timePart.split(':');
        if (parts.length == 2) {
          var hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          if (isPM && hour != 12) hour += 12;
          if (isAM && hour == 12) hour = 0;
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
      // Fallback: try ISO parse
      final dt = DateTime.parse(timeStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // Last resort: return as-is if it looks like a time
      return timeStr.length <= 8 ? timeStr : '--:--';
    }
  }

  String _formatDayAbbrev(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return DateFormat.E(Localizations.localeOf(context).languageCode).format(dt);
  }

  /// Map WeatherAPI.com condition codes to Material icons.
  /// See https://www.weatherapi.com/docs/weather_conditions.json
  IconData _getWeatherIcon(int code) {
    // Sunny / Clear
    if (code == 1000) return Icons.wb_sunny_rounded;
    // Partly cloudy
    if (code == 1003) return Icons.cloud_rounded;
    // Cloudy / Overcast
    if (code == 1006 || code == 1009) return Icons.cloud_rounded;
    // Mist / Fog / Freezing fog
    if (code == 1030 || code == 1135 || code == 1147) return Icons.foggy;
    // Drizzle variants (1150-1171) and light rain
    if (code >= 1150 && code <= 1171) return Icons.grain_rounded;
    // Rain variants (1180-1201)
    if (code >= 1180 && code <= 1201) return Icons.water_drop_rounded;
    // Snow / sleet / ice (1066, 1069, 1072, 1114, 1117, 1204-1237, 1255-1264)
    if (code == 1066 || code == 1069 || code == 1072 ||
        code == 1114 || code == 1117 ||
        (code >= 1204 && code <= 1237) ||
        (code >= 1255 && code <= 1264)) {
      return Icons.ac_unit_rounded;
    }
    // Rain showers (1240-1246)
    if (code >= 1240 && code <= 1246) return Icons.water_drop_rounded;
    // Snow showers (1249-1258) — already covered above
    // Thunderstorm (1087, 1273-1282)
    if (code == 1087 || code >= 1273) return Icons.thunderstorm_rounded;
    // Patchy rain/drizzle/snow possible (1063, 1066, etc.)
    if (code == 1063) return Icons.grain_rounded;
    return Icons.cloud_rounded;
  }

  /// Use condition_text from API when available, fall back to code-based description.
  String _getWeatherDescription(int code, [String conditionText = '']) {
    if (conditionText.isNotEmpty) return conditionText;
    final t = AppLocalizations.of(context).translate;
    // Fallback mapping for WeatherAPI.com codes
    if (code == 1000) return t('wx_clear');
    if (code == 1003) return t('wx_partly_cloudy');
    if (code == 1006) return t('wx_cloudy');
    if (code == 1009) return t('wx_overcast');
    if (code == 1030) return t('wx_mist');
    if (code == 1135 || code == 1147) return t('wx_foggy');
    if (code >= 1150 && code <= 1171) return t('wx_drizzle');
    if (code >= 1180 && code <= 1201) return t('wx_rain');
    if (code >= 1204 && code <= 1237) return t('wx_snow');
    if (code >= 1240 && code <= 1246) return t('wx_rain_showers');
    if (code >= 1255 && code <= 1264) return t('wx_snow_showers');
    if (code == 1087 || code >= 1273) return t('wx_thunderstorm');
    return t('unknown');
  }
}

// --- Add City Dialog (stateful, with debounced search via backend proxy) ---

class _AddCityDialog extends StatefulWidget {
  final Future<void> Function(String name, double lat, double lon) onCitySelected;

  const _AddCityDialog({required this.onCitySelected});

  @override
  State<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<_AddCityDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_GeoResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final results = await ApiService().searchWeatherCities(query);
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _results = results.map((r) => _GeoResult(
          name: (r['name'] as String?) ?? '',
          country: (r['country'] as String?) ?? '',
          admin1: (r['region'] as String?) ?? '',
          lat: (r['lat'] as num?)?.toDouble() ?? 0,
          lon: (r['lon'] as num?)?.toDouble() ?? 0,
        )).toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _results = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.translate('wx_add_city')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.translate('wx_city_name'),
                hintText: l10n.translate('wx_search_city'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_hasSearched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.translate('wx_no_results'),
                  style: TextStyle(color: Ds.muted(context)),
                ),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    final subtitle = [r.admin1, r.country]
                        .where((s) => s.isNotEmpty)
                        .join(', ');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: AppColors.burundiGreen),
                      title: Text(r.name),
                      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onCitySelected(
                          subtitle.isNotEmpty ? '${r.name}, ${r.country}' : r.name,
                          r.lat,
                          r.lon,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.translate('cancel')),
        ),
      ],
    );
  }
}

// --- Data classes ---

class _GeoResult {
  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;
  _GeoResult({required this.name, required this.country, required this.admin1, required this.lat, required this.lon});
}

class _CityWeather {
  final String name;
  final double lat;
  final double lon;
  final int? cityId;
  final String? backgroundImageUrl;
  double currentTemp = 0;
  /// Last fetch failed — render a placeholder instead of a fake 0°.
  bool fetchFailed = false;
  int humidity = 0;
  double windSpeed = 0;
  int weatherCode = 0;
  double feelsLike = 0;
  double uvIndex = 0;
  String conditionText = '';
  String conditionIcon = '';
  String sunrise = '';
  String sunset = '';
  List<_DayForecast> forecast = [];

  _CityWeather({
    required this.name,
    required this.lat,
    required this.lon,
    this.cityId,
    this.backgroundImageUrl,
  });
}

class _DayForecast {
  final String date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final String conditionText;
  final int chanceOfRain;

  _DayForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    this.conditionText = '',
    this.chanceOfRain = 0,
  });
}
