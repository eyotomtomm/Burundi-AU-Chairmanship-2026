import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/event_registration_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/haptic_service.dart';
import '../../services/content_cache_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/translate_button.dart';
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
  String? _ydBannerUrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final bannerUrl = ydSettings['banner_image_url']?.toString() ?? '';

      if (!mounted) return;
      // Cache on success
      ContentCacheService().cacheEvents(events);
      setState(() {
        _allEvents = events;
        _ydBannerUrl = bannerUrl.isNotEmpty ? Environment.fixMediaUrl(bannerUrl) : null;
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
      _allEvents.where((e) => !e.isEventPast).toList()
        ..sort((a, b) {
          if (a.isYouthDialogue != b.isYouthDialogue) {
            return a.isYouthDialogue ? -1 : 1;
          }
          return (a.eventDate ?? DateTime(2099)).compareTo(b.eventDate ?? DateTime(2099));
        });

  List<EventRegistrationModel> get _pastEvents =>
      _allEvents.where((e) => e.isEventPast).toList()
        ..sort((a, b) => (b.eventDate ?? DateTime(2000)).compareTo(a.eventDate ?? DateTime(2000)));

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'fr' ? '\u00c9v\u00e9nements' : 'Events'),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.burundiGreen, Color(0xFF0A5C1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: lang == 'fr' ? 'Calendrier' : 'Calendar',
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          const TranslateButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.auGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: lang == 'fr' ? 'Tous' : 'All'),
            Tab(text: lang == 'fr' ? '\u00c0 venir' : 'Upcoming'),
            Tab(text: lang == 'fr' ? 'Pass\u00e9s' : 'Past'),
          ],
        ),
      ),
      body: _isLoading
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
                    _buildEventList(_allEvents, lang, isDark, showEmpty: true),
                    _buildEventList(_upcomingEvents, lang, isDark, emptyMessage: lang == 'fr' ? 'De nouveaux événements arrivent bientôt' : 'New events coming soon'),
                    _buildEventList(_pastEvents, lang, isDark, emptyMessage: lang == 'fr' ? 'Les événements passés apparaîtront ici' : 'Past events will appear here'),
                  ],
                ),
    );
  }

  Widget _buildEventList(List<EventRegistrationModel> events, String lang, bool isDark, {bool showEmpty = false, String? emptyMessage}) {
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    if (events.isEmpty && !isAuth) {
      return _buildSignInPrompt(lang, isDark);
    }

    if (events.isEmpty) {
      return _buildEmpty(lang, isDark, emptyMessage);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticService.medium();
        await _loadData();
      },
      color: AppColors.burundiGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: events.length,
        itemBuilder: (context, index) => _buildEventCard(events[index], lang, isDark),
      ),
    );
  }

  Widget _buildEventCard(EventRegistrationModel event, String lang, bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isPast = event.isEventPast;
    final hasVenue = event.getVenue(lang).isNotEmpty;

    // Status badge
    String statusLabel;
    Color statusColor;
    IconData statusIcon;
    if (isPast) {
      statusLabel = lang == 'fr' ? 'Termin\u00e9' : 'Ended';
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_outline;
    } else if (event.hasRegistered) {
      statusLabel = lang == 'fr' ? 'Inscrit' : 'Registered';
      statusColor = AppColors.burundiGreen;
      statusIcon = Icons.how_to_reg;
    } else if (event.isRegistrationEnabled && event.isRegistrationOpen) {
      statusLabel = lang == 'fr' ? 'Inscription ouverte' : 'Registration Open';
      statusColor = AppColors.auGold;
      statusIcon = Icons.app_registration;
    } else if (event.isRegistrationEnabled && !event.isRegistrationOpen) {
      statusLabel = lang == 'fr' ? 'Inscription ferm\u00e9e' : 'Registration Closed';
      statusColor = AppColors.burundiRed;
      statusIcon = Icons.event_busy;
    } else {
      statusLabel = lang == 'fr' ? 'Information' : 'Info';
      statusColor = AppColors.lightTextSecondary;
      statusIcon = Icons.info_outline;
    }

    // Event type badge
    String typeLabel;
    IconData typeIcon;
    Color typeColor;
    switch (event.eventType) {
      case 'online':
        typeLabel = lang == 'fr' ? 'En ligne' : 'Online';
        typeIcon = Icons.videocam;
        typeColor = AppColors.burundiGreen;
        break;
      case 'hybrid':
        typeLabel = lang == 'fr' ? 'Hybride' : 'Hybrid';
        typeIcon = Icons.swap_horiz;
        typeColor = Colors.deepPurple;
        break;
      case 'info':
        typeLabel = 'Info';
        typeIcon = Icons.info_outline;
        typeColor = AppColors.lightTextSecondary;
        break;
      default:
        typeLabel = lang == 'fr' ? 'En personne' : 'In Person';
        typeIcon = Icons.location_on;
        typeColor = AppColors.burundiGreen;
    }

    return GestureDetector(
      onTap: () {
        HapticService.light();
        if (event.isYouthDialogue) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const YouthDialogueMainScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event, scrollToComments: false)),
          );
        }
      },
      child: Opacity(
        opacity: isPast ? 0.7 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image or gradient header
              if ((event.eventPoster != null && event.eventPoster!.isNotEmpty) ||
                  (event.isYouthDialogue && _ydBannerUrl != null))
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: event.eventPoster?.isNotEmpty == true
                            ? event.eventPoster!
                            : _ydBannerUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, s) => Container(
                          height: 180,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, u, e) => Container(
                          height: 180,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            gradient: LinearGradient(
                              colors: [AppColors.burundiGreen, Color(0xFF0A5C1E)],
                            ),
                          ),
                          child: const Center(child: Icon(Icons.event, size: 48, color: Colors.white54)),
                        ),
                      ),
                    ),
                    // Dark gradient overlay at bottom for readability
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                          ),
                        ),
                      ),
                    ),
                    // Status badge
                    Positioned(
                      top: 10, right: 10,
                      child: _buildBadge(statusLabel, statusColor, statusIcon),
                    ),
                    // Type badge
                    Positioned(
                      top: 10, left: 10,
                      child: _buildBadge(typeLabel, typeColor, typeIcon),
                    ),
                    // Date overlay at bottom
                    if (event.eventDate != null)
                      Positioned(
                        bottom: 8, left: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(event, lang),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else
                Container(
                  height: 100,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [AppColors.burundiGreen, Color(0xFF0A5C1E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.event, size: 40, color: Colors.white30)),
                      Positioned(
                        top: 10, right: 10,
                        child: _buildBadge(statusLabel, statusColor, statusIcon),
                      ),
                      Positioned(
                        top: 10, left: 10,
                        child: _buildBadge(typeLabel, typeColor, typeIcon),
                      ),
                      if (event.eventDate != null)
                        Positioned(
                          bottom: 10, left: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(event, lang),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.getCategoryName(lang) != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _hexToColor(event.categoryColor ?? '#455A64').withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.getCategoryName(lang)!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _hexToColor(event.categoryColor ?? '#455A64'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      event.getTitle(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                    if (event.getDescription(lang).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.getDescription(lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Info chips row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (hasVenue)
                          _buildInfoChip(Icons.location_on_outlined, event.getVenue(lang), textSecondary),
                        if (event.spotsRemaining != null && event.isRegistrationOpen && !isPast)
                          _buildInfoChip(
                            Icons.people_outline,
                            lang == 'fr'
                                ? '${event.spotsRemaining} places'
                                : '${event.spotsRemaining} spots',
                            event.spotsRemaining! < 10 ? AppColors.burundiRed : textSecondary,
                          ),
                        if (event.isMultiDay)
                          _buildInfoChip(
                            Icons.date_range,
                            lang == 'fr' ? '${event.totalDays} jours' : '${event.totalDays} days',
                            textSecondary,
                          ),
                        if (event.currentDayNumber != null)
                          _buildInfoChip(
                            Icons.play_circle_outline,
                            lang == 'fr'
                                ? 'Jour ${event.currentDayNumber}/${event.totalDays}'
                                : 'Day ${event.currentDayNumber}/${event.totalDays}',
                            AppColors.burundiGreen,
                          ),
                      ],
                    ),
                    // Countdown for upcoming events
                    if (!isPast && event.timeUntilEvent != null && event.timeUntilEvent!.inDays <= 7) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.auGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.auGold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: AppColors.auGold),
                            const SizedBox(width: 6),
                            Text(
                              _formatCountdown(event.timeUntilEvent!, lang),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.auGold,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppColors.lightTextSecondary;
    }
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _formatDate(EventRegistrationModel event, String lang) {
    final fmt = DateFormat('MMM d, yyyy', lang);
    if (event.eventDate == null) return lang == 'fr' ? 'Date \u00e0 confirmer' : 'Date TBC';
    final start = fmt.format(event.eventDate!);
    if (event.eventEndDate != null && event.isMultiDay) {
      return '$start - ${fmt.format(event.eventEndDate!)}';
    }
    final time = DateFormat('HH:mm').format(event.eventDate!);
    return '$start \u2022 $time';
  }

  String _formatCountdown(Duration d, String lang) {
    if (d.inDays > 0) {
      return lang == 'fr'
          ? 'Dans ${d.inDays}j ${d.inHours % 24}h'
          : 'In ${d.inDays}d ${d.inHours % 24}h';
    }
    if (d.inHours > 0) {
      return lang == 'fr'
          ? 'Dans ${d.inHours}h ${d.inMinutes % 60}m'
          : 'In ${d.inHours}h ${d.inMinutes % 60}m';
    }
    return lang == 'fr'
        ? 'Dans ${d.inMinutes}min'
        : 'In ${d.inMinutes}min';
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
