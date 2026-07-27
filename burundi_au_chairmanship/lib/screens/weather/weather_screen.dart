import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../models/api_models.dart';
import '../../config/environment.dart';

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
    int failCount = 0;
    for (final city in _cities) {
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
          failCount++;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Weather fetch failed for ${city.name}: $e');
        failCount++;
      }
    }
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
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.burundiGreen,
              onPressed: _showAddCityDialog,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _isLoading
          ? CustomScrollView(
              slivers: [
                // Always render the AppBar so users can go back during loading
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  backgroundColor: const Color(0xFF2D6E31),
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
                          colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.burundiGreen),
                        SizedBox(height: 16),
                        Text(
                          'Loading weather data…',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _hasError
              ? CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 280,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      backgroundColor: const Color(0xFF2D6E31),
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
                              colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 56,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Could not load weather data',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your connection and try again.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadCitiesAndFetch,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.burundiGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _fetchWeather();
              },
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
                    backgroundColor: const Color(0xFF2D6E31),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        l10n.translate('weather'),
                        style: const TextStyle(
                          fontFamily: 'HeatherGreen',
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),

                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background image (blurred) from backend
                          if (primary?.backgroundImageUrl != null && primary!.backgroundImageUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: Environment.fixMediaUrl(primary.backgroundImageUrl!),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                                ),
                              ),
                            ),

                          // Blur effect
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),

                          // Gradient overlay for better text contrast
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.burundiGreen.withValues(alpha: 0.7),
                                  const Color(0xFF2D6E31).withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),

                          // Content
                          SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            child: primary != null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Location label
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: AppColors.auGold, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            primary.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Weather icon in tinted circle
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                        child: Icon(
                                          _getWeatherIcon(primary.weatherCode),
                                          size: 36,
                                          color: AppColors.auGold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Large temperature
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            primary.currentTemp.toStringAsFixed(0),
                                            style: const TextStyle(
                                              fontSize: 56,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              '°C',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      // Description
                                      Text(
                                        _getWeatherDescription(primary.weatherCode, primary.conditionText),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        ],
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
                      _getWeatherDescription(city.weatherCode, city.conditionText),
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
        text: 'Rain right now — carry an umbrella!',
      );
    }
    if (forecastRain || maxChance >= 50) {
      return (
        icon: Icons.umbrella_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.08),
        text: maxChance > 0
            ? '$maxChance% chance of rain in the next few days — pack an umbrella.'
            : 'Rain expected in the next few days — pack an umbrella.',
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
        (code >= 1255 && code <= 1264)) return Icons.ac_unit_rounded;
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
    // Fallback mapping for WeatherAPI.com codes
    if (code == 1000) return 'Clear';
    if (code == 1003) return 'Partly cloudy';
    if (code == 1006) return 'Cloudy';
    if (code == 1009) return 'Overcast';
    if (code == 1030) return 'Mist';
    if (code == 1135 || code == 1147) return 'Foggy';
    if (code >= 1150 && code <= 1171) return 'Drizzle';
    if (code >= 1180 && code <= 1201) return 'Rain';
    if (code >= 1204 && code <= 1237) return 'Snow';
    if (code >= 1240 && code <= 1246) return 'Rain showers';
    if (code >= 1255 && code <= 1264) return 'Snow showers';
    if (code == 1087 || code >= 1273) return 'Thunderstorm';
    return 'Unknown';
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
