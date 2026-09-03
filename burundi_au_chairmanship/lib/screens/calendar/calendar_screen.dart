import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../l10n/app_localizations.dart';
import '../../models/location_model.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/ds/ds_widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  List<EventLocation>? _events;
  bool _isLoading = true;

  /// First day of the month currently shown in the grid.
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

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

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Days in the shown month that have at least one event.
  Set<int> get _eventDays => {
        for (final e in _events ?? const <EventLocation>[])
          if (e.eventDate.year == _month.year && e.eventDate.month == _month.month)
            e.eventDate.day
      };

  List<EventLocation> get _dayEvents {
    final day = _selectedDay;
    if (day == null || _events == null) return const [];
    return _events!.where((e) => _dayOf(e.eventDate) == day).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('calendar')),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: langCode == 'fr' ? "Aujourd'hui" : 'Today',
            onPressed: () => setState(() {
              final now = DateTime.now();
              _month = DateTime(now.year, now.month);
              _selectedDay = _dayOf(now);
            }),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const ShimmerCalendarSkeleton()
          : RefreshIndicator(
              color: Ds.green,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadEvents();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _buildMonthGrid(langCode),
                  if (_events == null || _events!.isEmpty)
                    _buildEmptyState(langCode)
                  else
                    ..._buildAgenda(langCode),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(String langCode) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
        child: Column(
          children: [
            Icon(Icons.calendar_today_rounded, size: 56, color: Ds.muted(context)),
            const SizedBox(height: 16),
            Text(
              langCode == 'fr' ? 'Calendrier en préparation' : 'Calendar being prepared',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Ds.ink(context)),
            ),
            const SizedBox(height: 8),
            Text(
              langCode == 'fr'
                  ? 'Les événements du sommet seront affichés ici dès leur publication.'
                  : 'Summit events will appear here once they are published.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context)),
            ),
          ],
        ),
      );

  Widget _buildMonthGrid(String langCode) {
    final locale = langCode == 'fr' ? 'fr_FR' : 'en_US';
    final monthLabel = DateFormat('MMMM yyyy', locale).format(_month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Monday-first grid, matching the M T W T F S S header in the comp.
    final leadingBlanks = _month.weekday - DateTime.monday;
    final eventDays = _eventDays;
    final today = _dayOf(DateTime.now());

    return DsCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _monthArrow(Icons.chevron_left_rounded, -1),
              Expanded(
                child: Text(monthLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Ds.ink(context))),
              ),
              _monthArrow(Icons.chevron_right_rounded, 1),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in _weekdayInitials(locale))
                Expanded(
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Ds.muted(context))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.15,
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _dayCell(day, eventDays.contains(day), today),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(Ds.green, langCode == 'fr' ? 'Sélectionné' : 'Selected'),
              const SizedBox(width: 14),
              _legendDot(Ds.greenTint, langCode == 'fr' ? 'Événements' : 'Event days',
                  outlined: true),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _weekdayInitials(String locale) {
    final fmt = DateFormat('EEEEE', locale);
    // 2024-01-01 was a Monday, so this walks Mon→Sun.
    return [for (var i = 0; i < 7; i++) fmt.format(DateTime(2024, 1, 1 + i))];
  }

  Widget _monthArrow(IconData icon, int delta) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(
            () => _month = DateTime(_month.year, _month.month + delta)),
        child: SizedBox(
            width: 34, height: 30, child: Icon(icon, size: 20, color: Ds.green)),
      );

  Widget _dayCell(int day, bool hasEvent, DateTime today) {
    final date = DateTime(_month.year, _month.month, day);
    final selected = _selectedDay == date;
    final isToday = date == today;

    Color? bg;
    Color fg = Ds.ink(context);
    FontWeight weight = FontWeight.w500;
    if (selected) {
      bg = Ds.green;
      fg = Colors.white;
      weight = FontWeight.w800;
    } else if (hasEvent) {
      bg = Ds.tint(context);
      fg = Ds.greenDeep;
      weight = FontWeight.w700;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = selected ? null : date),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Ds.rIcon),
          border: !selected && isToday
              ? Border.all(color: Ds.green, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text('$day',
            style: TextStyle(fontSize: 13, fontWeight: weight, color: fg)),
      ),
    );
  }

  Widget _legendDot(Color color, String label, {bool outlined = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: outlined ? Border.all(color: Ds.green) : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: Ds.muted(context))),
        ],
      );

  /// Either the selected day's events, or every upcoming day grouped by date.
  List<Widget> _buildAgenda(String langCode) {
    final locale = langCode == 'fr' ? 'fr_FR' : 'en_US';
    final headingFormat = DateFormat('EEEE d MMMM', locale);

    if (_selectedDay != null) {
      final events = _dayEvents;
      return [
        DsGroupLabel(headingFormat.format(_selectedDay!),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 8)),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Text(
                langCode == 'fr'
                    ? 'Aucun événement ce jour-là.'
                    : 'No events on this day.',
                style: TextStyle(fontSize: 13, color: Ds.body(context))),
          )
        else
          ...events.map((e) => _EventCard(
                event: e,
                langCode: langCode,
                onAddToCalendar: () => _addToCalendar(e),
              )),
      ];
    }

    final grouped = <String, List<EventLocation>>{};
    for (final event in _events!) {
      grouped.putIfAbsent(headingFormat.format(event.eventDate), () => []).add(event);
    }
    return [
      for (final entry in grouped.entries) ...[
        DsGroupLabel(entry.key, padding: const EdgeInsets.fromLTRB(22, 4, 22, 8)),
        ...entry.value.map((e) => _EventCard(
              event: e,
              langCode: langCode,
              onAddToCalendar: () => _addToCalendar(e),
            )),
        const SizedBox(height: 8),
      ],
    ];
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

    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: Ds.green,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.getName(langCode), style: Ds.cardTitle(context)),
                  const SizedBox(height: 3),
                  Text(
                    '${timeFormat.format(event.eventDate)} · ${event.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ds.cardBody(context),
                  ),
                  const SizedBox(height: 10),
                  DsOutlineButton(
                    langCode == 'fr' ? 'Ajouter au calendrier' : 'Add to calendar',
                    icon: Icons.calendar_month_rounded,
                    radius: Ds.rPill,
                    onTap: onAddToCalendar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
