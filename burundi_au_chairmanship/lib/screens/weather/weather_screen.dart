import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  static const _defaultCities = [
    _CityData(name: 'Bujumbura', lat: -3.3731, lon: 29.3644),
    _CityData(name: 'Addis Ababa', lat: 9.0192, lon: 38.7525),
  ];
  static const _prefsKey = 'custom_weather_cities';

  final List<_CityWeather> _cities = [];
  bool _isLoading = true;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadCitiesAndFetch();
  }

  Future<void> _loadCitiesAndFetch() async {
    // Always start with defaults
    _cities.clear();
    for (final d in _defaultCities) {
      _cities.add(_CityWeather(name: d.name, lat: d.lat, lon: d.lon));
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

  Future<void> _fetchWeather() async {
    setState(() => _isLoading = true);
    for (final city in _cities) {
      try {
        final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${city.lat}&longitude=${city.lon}'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,apparent_temperature,uv_index'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset'
          '&timezone=auto&forecast_days=3',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          city.currentTemp = (data['current']['temperature_2m'] as num).toDouble();
          city.humidity = (data['current']['relative_humidity_2m'] as num).toInt();
          city.windSpeed = (data['current']['wind_speed_10m'] as num).toDouble();
          city.weatherCode = (data['current']['weather_code'] as num).toInt();
          city.feelsLike = (data['current']['apparent_temperature'] as num).toDouble();
          city.uvIndex = (data['current']['uv_index'] as num).toDouble();

          final daily = data['daily'];
          city.sunrise = daily['sunrise'][0] as String;
          city.sunset = daily['sunset'][0] as String;

          city.forecast = [];
          for (int i = 0; i < 3; i++) {
            city.forecast.add(_DayForecast(
              date: daily['time'][i] as String,
              maxTemp: (daily['temperature_2m_max'][i] as num).toDouble(),
              minTemp: (daily['temperature_2m_min'][i] as num).toDouble(),
              weatherCode: (daily['weather_code'][i] as num).toInt(),
            ));
          }
        }
      } catch (_) {
        // Use fallback data
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _fetchWeatherForCity(_CityWeather city) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.lat}&longitude=${city.lon}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,apparent_temperature,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset'
        '&timezone=auto&forecast_days=3',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        city.currentTemp = (data['current']['temperature_2m'] as num).toDouble();
        city.humidity = (data['current']['relative_humidity_2m'] as num).toInt();
        city.windSpeed = (data['current']['wind_speed_10m'] as num).toDouble();
        city.weatherCode = (data['current']['weather_code'] as num).toInt();
        city.feelsLike = (data['current']['apparent_temperature'] as num).toDouble();
        city.uvIndex = (data['current']['uv_index'] as num).toDouble();

        final daily = data['daily'];
        city.sunrise = daily['sunrise'][0] as String;
        city.sunset = daily['sunset'][0] as String;

        city.forecast = [];
        for (int i = 0; i < 3; i++) {
          city.forecast.add(_DayForecast(
            date: daily['time'][i] as String,
            maxTemp: (daily['temperature_2m_max'][i] as num).toDouble(),
            minTemp: (daily['temperature_2m_min'][i] as num).toDouble(),
            weatherCode: (daily['weather_code'][i] as num).toInt(),
          ));
        }
      }
    } catch (_) {
      // Use fallback data
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove City'),
        content: Text('Remove ${city.name} from your weather list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _cities.isNotEmpty ? _cities.first : null;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.burundiGreen,
        onPressed: _showAddCityDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchWeather,
              color: AppColors.burundiGreen,
              child: CustomScrollView(
                slivers: [
                  // --- Gradient hero header with Bujumbura ---
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    backgroundColor: const Color(0xFF065A1A),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        l10n.translate('weather'),
                        style: const TextStyle(
                          fontFamily: 'HeatherGreen',
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.burundiGreen, Color(0xFF065A1A)],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
                            child: primary != null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Location label
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: AppColors.auGold, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            primary.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Weather icon in tinted circle
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                        child: Icon(
                                          _getWeatherIcon(primary.weatherCode),
                                          size: 44,
                                          color: AppColors.auGold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Large temperature
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            primary.currentTemp.toStringAsFixed(0),
                                            style: TextStyle(
                                              fontSize: 64,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              '°C',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Description
                                      Text(
                                        _getWeatherDescription(primary.weatherCode),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- Last updated timestamp ---
                  if (_lastUpdated != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          'Updated ${_formatTime(_lastUpdated!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // --- City weather cards ---
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final isDefault = _isDefaultCity(index);
                          final card = _buildCityCard(_cities[index], isDark);
                          if (isDefault) return card;
                          return GestureDetector(
                            onLongPress: () => _showRemoveCityDialog(index),
                            child: card,
                          );
                        },
                        childCount: _cities.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCityCard(_CityWeather city, bool isDark) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- City name row ---
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: AppColors.auGold),
                const SizedBox(width: 6),
                Text(
                  city.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Icon + temp + description ---
            Row(
              children: [
                // Weather icon in tinted circle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    _getWeatherIcon(city.weatherCode),
                    size: 36,
                    color: AppColors.auGold,
                  ),
                ),
                const SizedBox(width: 16),
                // Temperature + description
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.currentTemp.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: AppColors.burundiGreen,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '°C',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getWeatherDescription(city.weatherCode),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Stats row: humidity, wind, feels-like, UV ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatChip(Icons.water_drop_rounded, '${city.humidity}%', 'Humidity', isDark),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.air_rounded, '${city.windSpeed.toStringAsFixed(1)} km/h', 'Wind', isDark),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.thermostat_rounded, '${city.feelsLike.toStringAsFixed(0)}°', 'Feels like', isDark),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.wb_sunny_outlined, city.uvIndex.toStringAsFixed(1), 'UV Index', isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Sunrise / Sunset row ---
            Row(
              children: [
                Expanded(
                  child: _buildSunChip(Icons.wb_twilight_rounded, _formatSunTime(city.sunrise), 'Sunrise', isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSunChip(Icons.nights_stay_rounded, _formatSunTime(city.sunset), 'Sunset', isDark),
                ),
              ],
            ),

            // --- Rain advisory ---
            const SizedBox(height: 14),
            _buildRainAdvisory(city, isDark),

            if (city.forecast.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              const SizedBox(height: 14),

              // --- 3-Day Forecast ---
              Text(
                '3-Day Forecast',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: city.forecast.map((day) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.burundiGreen.withValues(alpha: isDark ? 0.08 : 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _formatDayAbbrev(day.date),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(_getWeatherIcon(day.weatherCode), size: 26, color: AppColors.auGold),
                          const SizedBox(height: 8),
                          Text(
                            '${day.maxTemp.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.minTemp.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.burundiGreen.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.burundiGreen),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSunChip(IconData icon, String time, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.auGold.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.auGold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isRainyCode(int code) {
    return (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;
  }

  ({IconData icon, Color color, Color bgColor, String text}) _getRainAdvisory(_CityWeather city, bool isDark) {
    final currentRain = _isRainyCode(city.weatherCode);
    final forecastRain = city.forecast.any((d) => _isRainyCode(d.weatherCode));

    if (currentRain) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.burundiRed,
        bgColor: AppColors.burundiRed.withValues(alpha: isDark ? 0.12 : 0.08),
        text: 'Rain right now — carry an umbrella!',
      );
    }
    if (forecastRain) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.08),
        text: 'Rain expected in the next few days — pack an umbrella.',
      );
    }
    return (
      icon: Icons.wb_sunny_rounded,
      color: AppColors.burundiGreen,
      bgColor: AppColors.burundiGreen.withValues(alpha: isDark ? 0.1 : 0.06),
      text: 'No rain expected — clear skies ahead.',
    );
  }

  Widget _buildRainAdvisory(_CityWeather city, bool isDark) {
    final advisory = _getRainAdvisory(city, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: advisory.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(advisory.icon, size: 20, color: advisory.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              advisory.text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatSunTime(String isoTime) {
    if (isoTime.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoTime);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      // Fallback: extract time from ISO string like "2026-02-24T06:15"
      final parts = isoTime.split('T');
      return parts.length > 1 ? parts[1].substring(0, 5) : '--:--';
    }
  }

  String _formatDayAbbrev(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } catch (_) {
      final parts = dateStr.split('-');
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = int.tryParse(parts[1]) ?? 1;
      return '${months[month]} ${parts[2]}';
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0 || code == 1) return Icons.wb_sunny_rounded;
    if (code == 2) return Icons.cloud_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 56 && code <= 57) return 'Freezing drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 66 && code <= 67) return 'Freezing rain';
    if (code >= 71 && code <= 75) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Unknown';
  }
}

// --- Add City Dialog (stateful, with debounced geocoding search) ---

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
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=5',
      );
      final response = await http.get(url);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? results = data['results'];
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _results = (results ?? []).map((r) => _GeoResult(
            name: r['name'] as String,
            country: (r['country'] as String?) ?? '',
            admin1: (r['admin1'] as String?) ?? '',
            lat: (r['latitude'] as num).toDouble(),
            lon: (r['longitude'] as num).toDouble(),
          )).toList();
        });
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _hasSearched = true;
            _results = [];
          });
        }
      }
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add City'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'City name',
                hintText: 'Search for a city...',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No results found',
                  style: TextStyle(color: Colors.grey),
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
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// --- Data classes ---

class _CityData {
  final String name;
  final double lat;
  final double lon;
  const _CityData({required this.name, required this.lat, required this.lon});
}

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
  double currentTemp = 0;
  int humidity = 0;
  double windSpeed = 0;
  int weatherCode = 0;
  double feelsLike = 0;
  double uvIndex = 0;
  String sunrise = '';
  String sunset = '';
  List<_DayForecast> forecast = [];

  _CityWeather({
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class _DayForecast {
  final String date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;

  _DayForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
  });
}
