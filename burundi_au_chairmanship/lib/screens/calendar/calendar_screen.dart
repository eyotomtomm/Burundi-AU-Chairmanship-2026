import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/location_model.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  List<EventLocation>? _events;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Rebuild when app returns from background (e.g., after calendar app closes)
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          // Force rebuild to ensure UI is properly restored
        });
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final api = ApiService();
      final events = await api.getEvents();
      if (!mounted) return;
      events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load events: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _events = []; // No fallback - show empty state
      });
    }
  }

  Future<void> _addToCalendar(EventLocation event) async {
    try {
      final langCode = Localizations.localeOf(context).languageCode;
      final startTime = event.eventDate;
      final endTime = startTime.add(const Duration(hours: 2));

      final calendarEvent = Event(
        title: event.getName(langCode),
        description: event.getDescription(langCode),
        location: event.address,
        startDate: startTime,
        endDate: endTime,
        allDay: false,
        iosParams: const IOSParams(
          reminder: Duration(minutes: 30),
          url: 'https://burundi.gov.bi',
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
      );

      final result = await Add2Calendar.addEvent2Cal(calendarEvent);

      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    langCode == 'fr'
                        ? 'Événement ajouté au calendrier'
                        : 'Event added to calendar',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to add event to calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'fr'
                  ? 'Échec de l\'ajout au calendrier'
                  : 'Failed to add to calendar',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('calendar')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.burundiGreen, Color(0xFF0A5C1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const ShimmerCalendarSkeleton()
          : _events == null || _events!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_events'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.burundiGreen,
                  onRefresh: _loadEvents,
                  child: _buildEventsList(langCode),
                ),
    );
  }

  Widget _buildEventsList(String langCode) {
    final grouped = <String, List<EventLocation>>{};
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy', langCode == 'fr' ? 'fr_FR' : 'en_US');

    for (final event in _events!) {
      final key = dateFormat.format(event.eventDate);
      grouped.putIfAbsent(key, () => []).add(event);
    }

    final entries = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final dateLabel = entries[index].key;
        final events = entries[index].value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.burundiGreen, AppColors.auGold],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.burundiGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...events.map((event) => _EventCard(
              event: event,
              langCode: langCode,
              onAddToCalendar: () => _addToCalendar(event),
            )),
            if (index < entries.length - 1) const Divider(height: 24),
          ],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventLocation event;
  final String langCode;
  final VoidCallback onAddToCalendar;

  const _EventCard({
    required this.event,
    required this.langCode,
    required this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.burundiGreen, Color(0xFF4CAF50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeFormat.format(event.eventDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.getName(langCode),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.getDescription(langCode),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.auGold),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.address,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.auGold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action buttons row
                    Row(
                      children: [
                        // Add to Calendar button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onAddToCalendar,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              langCode == 'fr' ? 'Ajouter au calendrier' : 'Add to Calendar',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.burundiGreen,
                              side: const BorderSide(color: AppColors.burundiGreen),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Set Reminder button
                        OutlinedButton.icon(
                          onPressed: onAddToCalendar,
                          icon: const Icon(Icons.notifications_outlined, size: 16),
                          label: Text(
                            langCode == 'fr' ? 'Rappel' : 'Remind',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.auGold,
                            side: const BorderSide(color: AppColors.auGold),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
