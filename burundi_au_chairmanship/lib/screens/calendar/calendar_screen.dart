import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/location_model.dart';
import '../../services/api_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<EventLocation>? _events;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _events = _fallbackEvents();
      });
    }
  }

  List<EventLocation> _fallbackEvents() {
    return [
      EventLocation(
        id: '1',
        name: 'AU Summit Opening Ceremony',
        nameFr: "Cérémonie d'ouverture du Sommet de l'UA",
        description: 'Official opening of the African Union Summit under Burundi Chairmanship.',
        descriptionFr: "Ouverture officielle du Sommet de l'Union africaine sous la présidence du Burundi.",
        address: 'AU Conference Centre, Addis Ababa',
        latitude: 9.0227,
        longitude: 38.7468,
        eventDate: DateTime(2026, 2, 15, 9, 0),
        imageUrl: '',
      ),
      EventLocation(
        id: '2',
        name: 'Heads of State Meeting',
        nameFr: "Réunion des chefs d'État",
        description: 'Assembly of heads of state and government.',
        descriptionFr: "Assemblée des chefs d'État et de gouvernement.",
        address: 'AU Conference Centre, Addis Ababa',
        latitude: 9.0227,
        longitude: 38.7468,
        eventDate: DateTime(2026, 2, 16, 10, 0),
        imageUrl: '',
      ),
      EventLocation(
        id: '3',
        name: 'Peace & Security Council',
        nameFr: 'Conseil de paix et de sécurité',
        description: 'Special session on continental peace and security.',
        descriptionFr: 'Session spéciale sur la paix et la sécurité continentales.',
        address: 'AU Headquarters, Addis Ababa',
        latitude: 9.0227,
        longitude: 38.7468,
        eventDate: DateTime(2026, 2, 17, 14, 0),
        imageUrl: '',
      ),
      EventLocation(
        id: '4',
        name: 'Cultural Gala Dinner',
        nameFr: 'Dîner de gala culturel',
        description: 'Celebrating Burundi culture and African unity.',
        descriptionFr: "Célébration de la culture burundaise et de l'unité africaine.",
        address: 'Sheraton Addis, Addis Ababa',
        latitude: 9.0127,
        longitude: 38.7568,
        eventDate: DateTime(2026, 2, 18, 19, 0),
        imageUrl: '',
      ),
      EventLocation(
        id: '5',
        name: 'Youth Forum',
        nameFr: 'Forum de la jeunesse',
        description: 'Engaging African youth in continental development.',
        descriptionFr: 'Engager la jeunesse africaine dans le développement continental.',
        address: 'UNECA, Addis Ababa',
        latitude: 9.0200,
        longitude: 38.7500,
        eventDate: DateTime(2026, 3, 5, 9, 0),
        imageUrl: '',
      ),
    ];
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
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
            ...events.map((event) => _EventCard(event: event, langCode: langCode)),
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

  const _EventCard({required this.event, required this.langCode});

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
