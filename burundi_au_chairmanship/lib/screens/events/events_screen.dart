import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../models/event_registration_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/haptic_service.dart';
import '../../services/content_cache_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/async_content_view.dart';
import 'event_detail_screen.dart';
import '../youth_dialogue/youth_dialogue_main_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  List<EventRegistrationModel> _allEvents = [];
  bool _isLoading = true;
  String? _error;
  bool _isYdBanned = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Keeps the pill filters in sync with swipes between tabs.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final api = ApiService();
      final isAuth = context.read<AuthProvider>().isAuthenticated;
      List<EventRegistrationModel> events = [];

      // Fetch events and youth dialogue banner in parallel
      final results = await Future.wait([
        () async {
          if (isAuth) {
            return await api.getEventRegistrations();
          } else {
            try { return await api.getEventRegistrations(); }
            catch (_) { return <EventRegistrationModel>[]; }
          }
        }(),
        api.youthDialogueSettings().catchError((_) => <String, dynamic>{}),
      ]);

      events = results[0] as List<EventRegistrationModel>;
      final ydSettings = results[1] as Map<String, dynamic>;
      final ydBanned = ydSettings['is_device_banned'] == true;

      if (!mounted) return;
      // Cache on success
      ContentCacheService().cacheEvents(events);
      setState(() {
        _allEvents = events;
        _isYdBanned = ydBanned;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Fall back to cache
      final cached = ContentCacheService().getEvents();
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _allEvents = cached;
          _isLoading = false;
          _error = null;
        });
        return;
      }
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<EventRegistrationModel> get _upcomingEvents =>
      _allEvents.where((e) => !e.isEventPast && !(_isYdBanned && e.isYouthDialogue)).toList()
        ..sort((a, b) {
          if (a.isYouthDialogue != b.isYouthDialogue) {
            return a.isYouthDialogue ? -1 : 1;
          }
          return (a.eventDate ?? DateTime(2099)).compareTo(b.eventDate ?? DateTime(2099));
        });

  List<EventRegistrationModel> get _pastEvents =>
      _allEvents.where((e) => e.isEventPast && !(_isYdBanned && e.isYouthDialogue)).toList()
        ..sort((a, b) => (b.eventDate ?? DateTime(2000)).compareTo(a.eventDate ?? DateTime(2000)));

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final fr = lang == 'fr';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(fr ? 'Événements' : 'Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: fr ? 'Calendrier' : 'Calendar',
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                _tabChip(0, fr ? 'Tous' : 'All'),
                const SizedBox(width: 8),
                _tabChip(1, fr ? 'À venir' : 'Upcoming'),
                const SizedBox(width: 8),
                _tabChip(2, fr ? 'Passés' : 'Past'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : _error != null
                    ? AsyncContentView(
                        state: AsyncContentState.error,
                        onRetry: _loadData,
                        onRefresh: () async => _loadData(),
                        child: const SizedBox.shrink(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildEventList(_allEvents, lang, isDark,
                              showEmpty: true, storageKey: 'events_all'),
                          _buildEventList(_upcomingEvents, lang, isDark,
                              emptyMessage: fr
                                  ? 'De nouveaux événements arrivent bientôt'
                                  : 'New events coming soon',
                              storageKey: 'events_upcoming'),
                          _buildEventList(_pastEvents, lang, isDark,
                              emptyMessage: fr
                                  ? 'Les événements passés apparaîtront ici'
                                  : 'Past events will appear here',
                              storageKey: 'events_past'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label) => DsFilterChip(
        label,
        selected: _tabController.index == index,
        onTap: () => setState(() => _tabController.animateTo(index)),
      );

  Widget _buildEventList(List<EventRegistrationModel> events, String lang, bool isDark,
      {bool showEmpty = false, String? emptyMessage, String storageKey = 'events'}) {
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    if (events.isEmpty && !isAuth) return _buildSignInPrompt(lang, isDark);
    if (events.isEmpty) return _buildEmpty(lang, isDark, emptyMessage);

    return RefreshIndicator(
      onRefresh: () async {
        HapticService.medium();
        await _loadData();
      },
      color: Ds.green,
      child: ListView.builder(
        key: PageStorageKey<String>(storageKey),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: events.length,
        itemBuilder: (context, index) => _buildEventCard(events[index], lang, isDark),
      ),
    );
  }

  /// Agenda row from the comp: time column, coloured rail, then the details.
  Widget _buildEventCard(EventRegistrationModel event, String lang, bool isDark) {
    final isAuth = context.read<AuthProvider>().isAuthenticated;
    final fr = lang == 'fr';
    final isPast = event.isEventPast;
    final venue = event.getVenue(lang);
    final date = event.eventDate;

    // The rail colour encodes urgency: green live/soon, gold open, grey past.
    final Color rail;
    if (isPast) {
      rail = Ds.outline(context);
    } else if (event.hasRegistered) {
      rail = Ds.green;
    } else if (event.isRegistrationEnabled && event.isRegistrationOpen) {
      rail = Ds.gold;
    } else {
      rail = Ds.outline(context);
    }

    final pills = <Widget>[
      if (isPast)
        DsPill(fr ? 'Terminé' : 'Ended', tone: DsTone.neutral, dense: true)
      else if (event.hasRegistered)
        DsPill(fr ? 'Inscrit' : 'Registered', dense: true)
      else if (event.isRegistrationEnabled && !event.isRegistrationOpen)
        DsPill(fr ? 'Inscription fermée' : 'Registration closed',
            tone: DsTone.gold, dense: true),
    ];

    return Opacity(
      opacity: isPast ? 0.7 : 1,
      child: DsCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: () {
          HapticService.light();
          if (!isAuth) {
            Navigator.pushNamed(context, '/auth');
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => event.isYouthDialogue
                  ? const YouthDialogueMainScreen()
                  : EventDetailScreen(event: event, scrollToComments: false),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      date == null ? '--:--' : DateFormat('HH:mm').format(date),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Ds.green),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null
                          ? (fr ? 'à confirmer' : 'TBC')
                          : DateFormat('d MMM', lang).format(date),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Ds.muted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 3,
                decoration:
                    BoxDecoration(color: rail, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.getTitle(lang),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: Ds.ink(context)),
                    ),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 15, color: Ds.body(context)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ds.cardBody(context)),
                          ),
                        ],
                      ),
                    ],
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: pills),
                    ],
                    if (!isPast &&
                        !event.hasRegistered &&
                        event.isRegistrationEnabled &&
                        event.isRegistrationOpen) ...[
                      const SizedBox(height: 8),
                      DsOutlineButton(fr ? "S'inscrire" : "Register",
                          radius: Ds.rPill),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ShimmerLoading(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(height: 180, radius: 16),
                  SizedBox(height: 12),
                  ShimmerBox(height: 20, width: 250, radius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(height: 14, width: 180, radius: 4),
                ],
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang, bool isDark, String? message) {
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return RefreshIndicator(
      onRefresh: () async {
        HapticService.medium();
        await _loadData();
      },
      color: AppColors.burundiGreen,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.event_note_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  message ?? (lang == 'fr' ? 'Événements en préparation' : 'Events being prepared'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'fr'
                      ? 'Les détails seront publiés ici dès qu\'ils seront disponibles.'
                      : 'Details will be published here once available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(String lang, bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    return RefreshIndicator(
      onRefresh: () async {
        HapticService.medium();
        await _loadData();
      },
      color: AppColors.burundiGreen,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 48, color: AppColors.burundiGreen.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  lang == 'fr'
                      ? 'Connectez-vous pour voir et vous inscrire aux \u00e9v\u00e9nements'
                      : 'Sign in to view and register for events',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(
                    lang == 'fr' ? 'Se connecter' : 'Sign In',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
