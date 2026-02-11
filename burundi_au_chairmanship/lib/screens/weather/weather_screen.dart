import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final List<_CityWeather> _cities = [
    _CityWeather(name: 'Bujumbura', lat: -3.3731, lon: 29.3644),
    _CityWeather(name: 'Addis Ababa', lat: 9.0192, lon: 38.7525),
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() => _isLoading = true);
    for (final city in _cities) {
      try {
        final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${city.lat}&longitude=${city.lon}'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min'
          '&timezone=auto&forecast_days=3',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          city.currentTemp = (data['current']['temperature_2m'] as num).toDouble();
          city.humidity = (data['current']['relative_humidity_2m'] as num).toInt();
          city.windSpeed = (data['current']['wind_speed_10m'] as num).toDouble();
          city.weatherCode = (data['current']['weather_code'] as num).toInt();

          final daily = data['daily'];
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
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('weather'),
          style: GoogleFonts.oswald(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchWeather,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _cities.map((city) => _buildCityCard(city, isDark)).toList(),
              ),
            ),
    );
  }

  Widget _buildCityCard(_CityWeather city, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City name + current temp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name,
                      style: GoogleFonts.oswald(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWeatherDescription(city.weatherCode),
                      style: GoogleFonts.oswald(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _getWeatherIcon(city.weatherCode),
                      size: 40,
                      color: AppColors.auGold,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${city.currentTemp.toStringAsFixed(0)}°C',
                      style: GoogleFonts.oswald(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.burundiGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Humidity + Wind
            Row(
              children: [
                _buildInfoChip(Icons.water_drop_rounded, '${city.humidity}%', 'Humidity', isDark),
                const SizedBox(width: 16),
                _buildInfoChip(Icons.air_rounded, '${city.windSpeed.toStringAsFixed(1)} km/h', 'Wind', isDark),
              ],
            ),

            if (city.forecast.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              const SizedBox(height: 12),

              // 3-day forecast
              Text(
                '3-Day Forecast',
                style: GoogleFonts.oswald(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: city.forecast.map((day) {
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          _formatDate(day.date),
                          style: GoogleFonts.oswald(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(_getWeatherIcon(day.weatherCode), size: 24, color: AppColors.auGold),
                        const SizedBox(height: 6),
                        Text(
                          '${day.maxTemp.toStringAsFixed(0)}°',
                          style: GoogleFonts.oswald(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText),
                        ),
                        Text(
                          '${day.minTemp.toStringAsFixed(0)}°',
                          style: GoogleFonts.oswald(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ],
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

  Widget _buildInfoChip(IconData icon, String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.burundiGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.burundiGreen),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText)),
              Text(label, style: GoogleFonts.oswald(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(parts[1]) ?? 1;
    return '${months[month]} ${parts[2]}';
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

class _CityWeather {
  final String name;
  final double lat;
  final double lon;
  double currentTemp;
  int humidity;
  double windSpeed;
  int weatherCode;
  List<_DayForecast> forecast;

  _CityWeather({
    required this.name,
    required this.lat,
    required this.lon,
    this.currentTemp = 0,
    this.humidity = 0,
    this.windSpeed = 0,
    this.weatherCode = 0,
    List<_DayForecast>? forecast,
  }) : forecast = forecast ?? [];
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
