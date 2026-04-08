import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/event_registration_model.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/events/event_countdown.dart';
import '../../widgets/events/event_info_card.dart';
import '../../widgets/translate_button.dart';
import '../../widgets/confetti_overlay.dart';
import 'event_ticket_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventRegistrationModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late EventRegistrationModel _event;
  Timer? _countdownTimer;
  Duration? _timeLeft;
  bool _isSubmitting = false;
  bool _showProxyForm = false;
  final _formKey = GlobalKey<FormState>();
  final _proxyFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _formControllers = {};
  final Map<String, dynamic> _formValues = {};

  // Speakers
  List<Map<String, dynamic>> _speakers = [];

  // Agenda items
  List<Map<String, dynamic>> _agendaItems = [];
  bool _loadingAgenda = true;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;
  final _commentController = TextEditingController();
  int? _replyingToId;
  String? _replyingToName;

  // Photos
  List<Map<String, dynamic>> _photos = [];
  bool _loadingPhotos = true;
  bool _uploadingPhoto = false;

  // Attendees
  List<Map<String, dynamic>> _attendees = [];
  bool _loadingAttendees = true;

  // Proxy form controllers
  final _proxyNameController = TextEditingController();
  final _proxyEmailController = TextEditingController();
  final _proxyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _initFormControllers();
    _startCountdown();
    _loadSpeakers();
    _loadAgendaItems();
    _loadComments();
    _loadPhotos();
    _loadAttendees();
  }

  void _initFormControllers() {
    const valueOnlyTypes = {'checkbox', 'select', 'radio', 'multi_checkbox', 'country'};
    for (final field in _event.formFields) {
      if (!valueOnlyTypes.contains(field.fieldType)) {
        _formControllers[field.fieldName] = TextEditingController();
      }
      // Initialize multi_checkbox with empty list
      if (field.fieldType == 'multi_checkbox') {
        _formValues[field.fieldName] = <String>[];
      }
    }
    // Auto-fill from user profile
    _autoFillFromProfile();
  }

  void _autoFillFromProfile() {
    final auth = context.read<AuthProvider>();

    // Map of common field names/types to profile values
    final autoFillMap = <String, String?>{
      'name': auth.userName,
      'full_name': auth.userName,
      'fullname': auth.userName,
      'email': auth.userEmail,
      'email_address': auth.userEmail,
      'phone': auth.phoneNumber,
      'phone_number': auth.phoneNumber,
      'nationality': auth.nationality,
    };

    for (final field in _event.formFields) {
      final key = field.fieldName.toLowerCase();
      // Auto-fill text controllers
      if (_formControllers.containsKey(field.fieldName)) {
        final value = autoFillMap[key];
        if (value != null && value.isNotEmpty) {
          _formControllers[field.fieldName]!.text = value;
        }
      }
      // Auto-fill country/select dropdowns for nationality
      if (field.fieldType == 'country' && auth.nationality != null && auth.nationality!.isNotEmpty) {
        _formValues[field.fieldName] = auth.nationality;
      }
    }
  }

  bool _hasAutoFilledFields() {
    return _formControllers.values.any((c) => c.text.isNotEmpty) ||
        _formValues.values.any((v) => v is String && v.isNotEmpty);
  }

  Future<void> _loadSpeakers() async {
    try {
      final speakers = await ApiService().getEventSpeakers(eventId: _event.id);
      if (mounted) {
        setState(() {
          _speakers = speakers;
        });
      }
    } catch (_) {
      // Speakers are optional, silently ignore errors
    }
  }

  Future<void> _loadAgendaItems() async {
    try {
      final items = await ApiService().getEventAgendaItems(_event.id);
      if (mounted) {
        setState(() {
          _agendaItems = items;
          _loadingAgenda = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAgenda = false);
    }
  }

  void _startCountdown() {
    _updateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    if (!mounted) return;
    setState(() {
      _timeLeft = _event.timeUntilEvent;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _formControllers.values) {
      c.dispose();
    }
    _commentController.dispose();
    _proxyNameController.dispose();
    _proxyEmailController.dispose();
    _proxyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Greeting / Holiday card → show 3D postcard UI
    if (_event.cardType == 'greeting') {
      return _buildGreetingScreen(context, langCode, isDark);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero poster
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.burundiGreen,
            actions: const [TranslateButton()],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_event.eventPoster != null && _event.eventPoster!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(_event.eventPoster!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _posterFallback(),
                      errorWidget: (context, url, error) => _posterFallback(),
                    )
                  else
                    _posterFallback(),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Title at the bottom
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Text(
                      _event.getTitle(langCode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Countdown timer
                  EventCountdown(
                    event: _event,
                    timeLeft: _timeLeft,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // Event info card
                  EventInfoCard(
                    event: _event,
                    langCode: langCode,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Multi-day event indicator
                  if (_event.isMultiDay)
                    _buildMultiDayIndicator(isDark),

                  // Add to Calendar button
                  if (_event.eventDate != null && !_event.isEventPast)
                    _buildAddToCalendarButton(isDark),
                  const SizedBox(height: 12),

                  // Spots remaining indicator
                  if (_event.isRegistrationEnabled && _event.maxRegistrations > 0)
                    _buildSpotsRemainingIndicator(isDark),

                  const SizedBox(height: 8),

                  // Speakers section
                  if (_speakers.isNotEmpty)
                    _buildSpeakersSection(isDark),

                  // Agenda section
                  if (!_loadingAgenda && _agendaItems.isNotEmpty)
                    _buildAgendaSection(isDark, langCode),

                  // Registration section
                  _buildRegistrationSection(context, langCode, isDark),

                  // Proxy registration
                  if (_event.allowProxyRegistration && _event.isRegistrationOpen && !_event.isEventPast)
                    _buildProxySection(context, langCode, isDark),

                  // Contact section
                  if (_event.contactEmail.isNotEmpty || _event.contactPhone.isNotEmpty)
                    _buildContactSection(context, isDark),

                  const SizedBox(height: 20),

                  // Photos section
                  _buildPhotosSection(isDark),

                  // Attendees section
                  _buildAttendeesSection(isDark),

                  // Comments section
                  _buildCommentsSection(isDark),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Greeting / Holiday Postcard Screen ─────────────────────

  Widget _buildGreetingScreen(BuildContext context, String langCode, bool isDark) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.userName ?? 'Friend';
    final title = _event.getTitle(langCode);
    final description = _event.getDescription(langCode);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F5F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 3D Postcard
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-0.02)
                ..rotateY(0.015),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 420),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(8, 16),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(-4, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background: poster image or festive gradient
                      if (_event.eventPoster != null && _event.eventPoster!.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: Environment.fixMediaUrl(_event.eventPoster!),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _greetingGradient(),
                            errorWidget: (context, url, error) => _greetingGradient(),
                          ),
                        )
                      else
                        Positioned.fill(child: _greetingGradient()),

                      // Overlay gradient for text readability
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Decorative corner ornaments
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _cornerOrnament(),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Transform.scale(scaleX: -1, child: _cornerOrnament()),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Transform.scale(scaleY: -1, child: _cornerOrnament()),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Transform.scale(scaleX: -1, scaleY: -1, child: _cornerOrnament()),
                      ),

                      // Card content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Decorative line
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.auGold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Title
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'HeatherGreen',
                                height: 1.2,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Decorative divider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 30, height: 1, color: AppColors.auGold.withValues(alpha: 0.5)),
                                const SizedBox(width: 8),
                                Icon(Icons.star, color: AppColors.auGold, size: 16),
                                const SizedBox(width: 8),
                                Container(width: 30, height: 1, color: AppColors.auGold.withValues(alpha: 0.5)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Personal greeting
                            Text(
                              'Dear $userName,',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.auGold,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(color: Colors.black38, blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description / wish message
                            if (description.isNotEmpty)
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 15,
                                  height: 1.6,
                                  letterSpacing: 0.3,
                                  shadows: const [
                                    Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Signature line
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.auGold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Burundi AU Chairmanship 2025',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Action buttons below the card
            Row(
              children: [
                Expanded(
                  child: _greetingActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: AppColors.burundiGreen,
                    isDark: isDark,
                    onTap: () {
                      // Share functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing coming soon!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (_event.contactEmail.isNotEmpty || _event.contactPhone.isNotEmpty)
                  Expanded(
                    child: _greetingActionButton(
                      icon: Icons.favorite_rounded,
                      label: 'Send Thanks',
                      color: AppColors.burundiRed,
                      isDark: isDark,
                      onTap: () {
                        if (_event.contactEmail.isNotEmpty) {
                          launchUrl(Uri.parse(
                            'mailto:${_event.contactEmail}?subject=Thank you - $title',
                          ), mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
              ],
            ),

            // Event date info
            if (_event.eventDate != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.auGold, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _formatFullDate(_event.eventDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _greetingGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF0D3B0F),
            Color(0xFF1A237E),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _cornerOrnament() {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _CornerOrnamentPainter()),
    );
  }

  Widget _greetingActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event, size: 80, color: Colors.white30),
      ),
    );
  }



  // ── Speakers Section ─────────────────────────────────────

  Widget _buildSpeakersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speakers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _speakers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final speaker = _speakers[index];
              final photoUrl = speaker['photo'] as String?;
              return SizedBox(
                width: 120,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.15),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(Environment.fixMediaUrl(photoUrl))
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(Icons.person, size: 32, color: AppColors.burundiGreen)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      speaker['name'] ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    if (speaker['title'] != null && (speaker['title'] as String).isNotEmpty)
                      Text(
                        speaker['title'],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    if (speaker['organization'] != null && (speaker['organization'] as String).isNotEmpty)
                      Text(
                        speaker['organization'],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.burundiGreen,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Agenda Section ───────────────────────────────────────

  Widget _buildAgendaSection(bool isDark, String langCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.view_timeline_rounded, color: AppColors.burundiGreen, size: 22),
            const SizedBox(width: 8),
            Text(
              langCode == 'fr' ? 'Programme' : 'Agenda',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._agendaItems.map((item) => _buildAgendaItemTile(item, isDark)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAgendaItemTile(Map<String, dynamic> item, bool isDark) {
    final title = item['title'] ?? '';
    final description = item['description'] ?? '';
    final speakerName = item['speaker_name'] as String?;
    final room = item['room'] as String? ?? '';
    final track = item['track'] as String? ?? '';
    final startTime = DateTime.tryParse(item['start_time'] ?? '');
    final endTime = DateTime.tryParse(item['end_time'] ?? '');

    String timeLabel = '';
    if (startTime != null && endTime != null) {
      final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      timeLabel = '$startStr - $endStr';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3), width: 2),
                ),
              ),
              Container(
                width: 2,
                height: 60,
                color: AppColors.burundiGreen.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.burundiGreen,
                      ),
                    ),
                  if (timeLabel.isNotEmpty) const SizedBox(height: 4),
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightText,
                    ),
                  ),
                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Speaker + Room + Track metadata
                  if (speakerName != null || room.isNotEmpty || track.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (speakerName != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_rounded, size: 14,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              const SizedBox(width: 4),
                              Text(
                                speakerName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (room.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.room_rounded, size: 14,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (track.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.auGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              track,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.auGold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Registration Section ──────────────────────────────────

  Widget _buildRegistrationSection(BuildContext context, String langCode, bool isDark) {
    // Already registered → show confirmation (takes priority regardless of status)
    if (_event.hasRegistered) {
      return _buildRegisteredConfirmation(langCode, isDark);
    }

    // Registration not enabled for this event type → hide everything quietly
    if (!_event.isRegistrationEnabled) {
      return const SizedBox.shrink();
    }

    // Registration IS enabled but closed/past → show "Registration Closed" banner
    if (!_event.isRegistrationOpen || _event.isEventPast) {
      return _buildRegistrationClosed(isDark);
    }

    // Registration is open → show registration form
    return _buildRegistrationForm(langCode, isDark);
  }

  Widget _buildRegisteredConfirmation(String langCode, bool isDark) {
    final confirmationMessage = _event.getConfirmationMessage(langCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFF0FFF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppColors.burundiGreen, size: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            "You're Registered!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.burundiGreen,
            ),
          ),
          if (_event.userSubmissionStatus != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(_event.userSubmissionStatus!).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _event.userSubmissionStatus!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(_event.userSubmissionStatus!),
                ),
              ),
            ),
          ],
          if (confirmationMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              confirmationMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
            ),
          ],

          // View Ticket button
          if (_event.userSubmissionId != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTicket(),
                icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                label: const Text('View Ticket'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burundiGreen,
                  side: const BorderSide(color: AppColors.burundiGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegistrationClosed(bool isDark) {
    final isFull = _event.maxRegistrations > 0 &&
        _event.currentRegistrationCount >= _event.maxRegistrations;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            isFull ? Icons.people : Icons.event_busy,
            color: Colors.grey,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            isFull ? 'Event Full' : 'Registration Closed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(String langCode, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.app_registration, color: AppColors.burundiGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Register for this Event',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Auto-fill hint
            if (_hasAutoFilledFields())
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppColors.burundiGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pre-filled from your profile. Review and submit.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.burundiGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Dynamic form fields
            ...(_event.formFields.where((f) => f.isActive).toList()
              ..sort((a, b) => a.order.compareTo(b.order)))
                .map((field) => _buildFormField(field, langCode, isDark)),

            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitRegistration(langCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: AppColors.burundiGreen.withValues(alpha: 0.5),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Register',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(RegistrationFormField field, String langCode, bool isDark) {
    final label = field.getLabel(langCode);
    final placeholder = field.getPlaceholder(langCode);
    final helpText = field.getHelpText(langCode);
    final textColor = isDark ? Colors.white70 : Colors.black87;

    switch (field.fieldType) {
      case 'textarea':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            maxLines: 4,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired),
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case 'select':
      case 'country':
        final options = field.fieldType == 'country'
            ? _countryList
            : field.options.map((o) => o.toString()).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            decoration: _inputDecoration(label, null, helpText, isDark, field.isRequired),
            hint: placeholder.isNotEmpty ? Text(placeholder) : null,
            isExpanded: true,
            menuMaxHeight: 300,
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => _formValues[field.fieldName] = val,
            validator: field.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case 'radio':
        final options = field.options.map((o) => o.toString()).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FormField<String>(
            initialValue: _formValues[field.fieldName] as String?,
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isRequired ? '$label *' : label,
                    style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (helpText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(helpText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final selected = _formValues[field.fieldName] == option;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _formValues[field.fieldName] = option);
                          state.didChange(option);
                        },
                        selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.burundiGreen : textColor,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.burundiGreen : (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        );

      case 'multi_checkbox':
        final options = field.options.map((o) => o.toString()).toList();
        final selected = (_formValues[field.fieldName] as List<String>?) ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FormField<List<String>>(
            initialValue: selected,
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Select at least one' : null : null,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isRequired ? '$label *' : label,
                    style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (helpText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(helpText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isChecked = selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isChecked,
                        onSelected: (val) {
                          setState(() {
                            final list = List<String>.from(selected);
                            if (val) {
                              list.add(option);
                            } else {
                              list.remove(option);
                            }
                            _formValues[field.fieldName] = list;
                          });
                          state.didChange(_formValues[field.fieldName] as List<String>);
                        },
                        selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.burundiGreen,
                        labelStyle: TextStyle(
                          color: isChecked ? AppColors.burundiGreen : textColor,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isChecked ? AppColors.burundiGreen : (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        );

      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CheckboxListTile(
            title: Text(label, style: TextStyle(color: textColor)),
            value: _formValues[field.fieldName] == true,
            onChanged: (val) => setState(() => _formValues[field.fieldName] = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.burundiGreen,
          ),
        );

      case 'date':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            readOnly: true,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired).copyWith(
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                _formControllers[field.fieldName]?.text =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case 'time':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            readOnly: true,
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired).copyWith(
              suffixIcon: const Icon(Icons.access_time, size: 18),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null && mounted) {
                _formControllers[field.fieldName]?.text =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              }
            },
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      default:
        // text, email, phone, number, passport, nationality, url
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _formControllers[field.fieldName],
            keyboardType: _getKeyboardType(field.fieldType),
            decoration: _inputDecoration(label, placeholder, helpText, isDark, field.isRequired),
            validator: field.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );
    }
  }

  InputDecoration _inputDecoration(String label, String? placeholder, String? helpText, bool isDark, bool required) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: placeholder,
      helperText: (helpText != null && helpText.isNotEmpty) ? helpText : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  TextInputType _getKeyboardType(String fieldType) {
    switch (fieldType) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'url':
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }

  // ── Proxy Registration ────────────────────────────────────

  Widget _buildProxySection(BuildContext context, String langCode, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showProxyForm = !_showProxyForm),
            icon: Icon(_showProxyForm ? Icons.expand_less : Icons.person_add),
            label: Text(_showProxyForm ? 'Hide Proxy Form' : 'Register for Someone Else'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.auGold,
              side: const BorderSide(color: AppColors.auGold),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Proxy form
        if (_showProxyForm) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.auGold.withValues(alpha: 0.3),
              ),
            ),
            child: Form(
              key: _proxyFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proxy Registration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Register on behalf of someone else',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _proxyNameController,
                    decoration: _inputDecoration('Full Name', 'Enter their full name', null, isDark, true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _proxyEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Email', 'Enter their email', null, isDark, true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _proxyPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('Phone', 'Enter their phone number', null, isDark, false),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitProxyRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.auGold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: AppColors.auGold.withValues(alpha: 0.5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Submit Proxy Registration',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Contact Section ───────────────────────────────────────

  Widget _buildContactSection(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Us',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_event.contactEmail.isNotEmpty)
            _contactButton(
              Icons.email_outlined,
              _event.contactEmail,
              () => launchUrl(Uri.parse('mailto:${_event.contactEmail}'), mode: LaunchMode.externalApplication),
              isDark,
            ),
          if (_event.contactPhone.isNotEmpty) ...[
            if (_event.contactEmail.isNotEmpty) const SizedBox(height: 8),
            _contactButton(
              Icons.phone_outlined,
              _event.contactPhone,
              () => launchUrl(Uri.parse('tel:${_event.contactPhone}'), mode: LaunchMode.externalApplication),
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactButton(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.burundiGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.burundiGreen,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Multi-day Indicator ─────────────────────────────────

  Widget _buildMultiDayIndicator(bool isDark) {
    final totalDays = _event.totalDays;
    final currentDay = _event.currentDayNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.burundiGreen.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            color: AppColors.burundiGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalDays-Day Event',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (currentDay != null)
                  Text(
                    'Day $currentDay of $totalDays',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.burundiGreen,
                    ),
                  )
                else if (_event.isEventPast)
                  Text(
                    'Event completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  )
                else
                  Text(
                    'Starts in ${_event.timeUntilEvent?.inDays ?? 0} days',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          // Progress dots for multi-day
          if (totalDays <= 10)
            Row(
              children: List.generate(totalDays, (i) {
                final dayNum = i + 1;
                final isCurrentDay = currentDay != null && dayNum == currentDay;
                final isPastDay = currentDay != null && dayNum < currentDay;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentDay
                        ? AppColors.burundiGreen
                        : isPastDay
                            ? AppColors.burundiGreen.withValues(alpha: 0.4)
                            : (isDark ? const Color(0xFF444444) : const Color(0xFFD0D0D0)),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // ── Add to Calendar ────────────────────────────────────

  Widget _buildAddToCalendarButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addToCalendar,
        icon: const Icon(Icons.calendar_month, size: 18),
        label: const Text('Add to Calendar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.burundiGreen,
          side: const BorderSide(color: AppColors.burundiGreen),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _addToCalendar() {
    if (_event.eventDate == null) return;

    final event = cal.Event(
      title: _event.eventTitle,
      description: _event.eventDescription,
      location: _event.venue.isNotEmpty
          ? '${_event.venue}, ${_event.venueAddress}'
          : _event.venueAddress,
      startDate: _event.eventDate!,
      endDate: _event.eventEndDate ?? _event.eventDate!.add(const Duration(hours: 2)),
    );

    cal.Add2Calendar.addEvent2Cal(event);
  }

  // ── Spots Remaining ────────────────────────────────────

  Widget _buildSpotsRemainingIndicator(bool isDark) {
    final spots = _event.spotsRemaining;
    final maxReg = _event.maxRegistrations;

    // If spots_remaining is null, the backend has unlimited capacity
    if (spots == null || maxReg <= 0) return const SizedBox.shrink();

    final percentage = spots / maxReg;
    final Color spotColor;
    final String urgencyText;

    if (spots <= 0) {
      spotColor = AppColors.burundiRed;
      urgencyText = 'Event Full';
    } else if (percentage < 0.2) {
      spotColor = AppColors.burundiRed;
      urgencyText = 'Almost full! $spots spot${spots == 1 ? '' : 's'} remaining';
    } else if (percentage < 0.5) {
      spotColor = Colors.orange;
      urgencyText = '$spots spot${spots == 1 ? '' : 's'} remaining';
    } else {
      spotColor = AppColors.burundiGreen;
      urgencyText = '$spots spot${spots == 1 ? '' : 's'} remaining';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: spotColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: spotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            spots <= 0 ? Icons.people : Icons.event_seat,
            color: spotColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              urgencyText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: spotColor,
              ),
            ),
          ),
          // Progress bar
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1.0 - percentage.clamp(0.0, 1.0),
                backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation(spotColor),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── View Ticket ─────────────────────────────────────────

  void _openTicket() {
    if (_event.userSubmissionId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventTicketScreen(submissionId: _event.userSubmissionId!),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _submitRegistration(String langCode) async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isSubmitting = true);

    // Gather form data
    final formData = <String, dynamic>{};
    for (final field in _event.formFields) {
      if (_formControllers.containsKey(field.fieldName)) {
        formData[field.fieldName] = _formControllers[field.fieldName]!.text;
      } else if (_formValues.containsKey(field.fieldName)) {
        formData[field.fieldName] = _formValues[field.fieldName];
      }
    }

    try {
      await ApiService().submitEventRegistration(_event.id, formData);
      if (!mounted) return;

      // Refresh event data
      final updated = await ApiService().getEventRegistration(_event.id);
      if (!mounted) return;
      setState(() {
        _event = updated;
        _isSubmitting = false;
      });

      // Trigger confetti celebration
      HapticFeedback.mediumImpact();
      ConfettiOverlay.show(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: AppColors.burundiGreen,
        ),
      );
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Try again.'), backgroundColor: AppColors.burundiRed),
      );
    }
  }

  Future<void> _submitProxyRegistration() async {
    if (!_proxyFormKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isSubmitting = true);

    try {
      await ApiService().submitProxyRegistration(
        eventId: _event.id,
        proxyName: _proxyNameController.text.trim(),
        proxyEmail: _proxyEmailController.text.trim(),
        proxyPhone: _proxyPhoneController.text.trim(),
      );
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _showProxyForm = false;
      });

      _proxyNameController.clear();
      _proxyEmailController.clear();
      _proxyPhoneController.clear();

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proxy registration submitted!'),
          backgroundColor: AppColors.burundiGreen,
        ),
      );
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proxy registration failed. Try again.'), backgroundColor: AppColors.burundiRed),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  String _formatFullDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.burundiGreen;
      case 'pending':
        return AppColors.auGold;
      case 'rejected':
        return AppColors.burundiRed;
      default:
        return Colors.grey;
    }
  }

  // ── Load Comments ──────────────────────────────────────

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService().getEventComments(_event.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  // ── Load Photos ───────────────────────────────────────

  Future<void> _loadPhotos() async {
    try {
      final photos = await ApiService().getEventPhotos(_event.id);
      if (mounted) {
        setState(() {
          _photos = photos;
          _loadingPhotos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  // ── Load Attendees ────────────────────────────────────

  Future<void> _loadAttendees() async {
    try {
      final attendees = await ApiService().getEventAttendees(_event.id);
      if (mounted) {
        setState(() {
          _attendees = attendees;
          _loadingAttendees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAttendees = false);
    }
  }

  // ── Comments Section ──────────────────────────────────

  Widget _buildCommentsSection(bool isDark) {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final topLevelComments = _comments.where((c) => c['parent'] == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppColors.burundiGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
            const SizedBox(width: 8),
            if (!_loadingComments)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${topLevelComments.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.burundiGreen,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Comment input
        if (isLoggedIn)
          _buildCommentInput(isDark, auth)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 8),
                Text(
                  'Sign in to post a comment',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Comments list
        if (_loadingComments)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (topLevelComments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No comments yet. Be the first!',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          )
        else
          ...topLevelComments.map((comment) => _buildCommentTile(comment, isDark, auth, isReply: false)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCommentInput(bool isDark, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyingToName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to $_replyingToName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.burundiGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToId = null;
                      _replyingToName = null;
                    }),
                    child: const Icon(Icons.close, size: 14, color: AppColors.burundiGreen),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.15),
                backgroundImage: auth.profilePictureUrl != null && auth.profilePictureUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(Environment.fixMediaUrl(auth.profilePictureUrl!))
                    : null,
                child: auth.profilePictureUrl == null || auth.profilePictureUrl!.isEmpty
                    ? Text(
                        (auth.userName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.burundiGreen),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: _replyingToName != null ? 'Write a reply...' : 'Write a comment...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _postingComment ? null : () => _submitComment(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _postingComment
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _postingComment = true);

    try {
      await ApiService().postEventComment(
        _event.id,
        content,
        parentId: _replyingToId,
      );
      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
      await _loadComments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment'), backgroundColor: AppColors.burundiRed),
        );
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, bool isDark, AuthProvider auth, {required bool isReply}) {
    final userName = comment['user_name'] ?? 'User';
    final userId = comment['user_id'] as int?;
    final content = comment['content'] ?? '';
    final createdAt = comment['created_at'] as String?;
    final profilePicture = comment['profile_picture'] as String?;
    final badgeType = comment['badge_type'] as String?;
    final replies = (comment['replies'] as List<dynamic>?) ?? [];
    final replyCount = comment['reply_count'] ?? replies.length;
    final commentId = comment['id'] as int?;
    final isOwner = auth.isAuthenticated && userId == auth.userId;

    String timeAgo = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgo = '${diff.inMinutes}m ago';
        } else {
          timeAgo = 'Just now';
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 40.0 : 0.0, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.15),
                backgroundImage: profilePicture != null && profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(Environment.fixMediaUrl(profilePicture))
                    : null,
                child: profilePicture == null || profilePicture.isEmpty
                    ? Text(
                        userName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: isReply ? 11 : 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.burundiGreen,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: isReply ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (badgeType != null && badgeType.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: badgeType == 'GOLD' ? const Color(0xFFD4AF37) : Colors.blue,
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black38,
                          ),
                        ),
                        const Spacer(),
                        if (isOwner && commentId != null)
                          GestureDetector(
                            onTap: () => _deleteComment(commentId),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildMentionRichText(content, isDark),
                    const SizedBox(height: 6),
                    if (!isReply && auth.isAuthenticated)
                      GestureDetector(
                        onTap: () => setState(() {
                          _replyingToId = commentId;
                          _replyingToName = userName;
                        }),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.burundiGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Nested replies
          if (!isReply && replies.isNotEmpty)
            ...replies.map((reply) => _buildCommentTile(
              reply as Map<String, dynamic>,
              isDark,
              auth,
              isReply: true,
            )),
          // Show reply count if there are more
          if (!isReply && replyCount > replies.length)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text(
                '${replyCount - replies.length} more replies...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.burundiGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build rich text with @mentions highlighted in blue
  Widget _buildMentionRichText(String content, bool isDark) {
    final mentionRegex = RegExp(r'@(\w+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(content)) {
      // Add text before the mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
        ));
      }
      // Add the mention in blue
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining text after the last mention
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black87,
          height: 1.4,
        ),
        children: spans.isEmpty ? [TextSpan(text: content)] : spans,
      ),
    );
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.burundiRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService().deleteEventComment(_event.id, commentId);
      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted'), backgroundColor: AppColors.burundiGreen),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment'), backgroundColor: AppColors.burundiRed),
        );
      }
    }
  }

  // ── Photos Section ────────────────────────────────────

  Widget _buildPhotosSection(bool isDark) {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, color: AppColors.burundiGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
            const SizedBox(width: 8),
            if (!_loadingPhotos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_photos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.burundiGreen,
                  ),
                ),
              ),
            const Spacer(),
            if (isLoggedIn)
              GestureDetector(
                onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_uploadingPhoto)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.add_a_photo, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text(
                        'Add',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingPhotos)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_photos.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 40,
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black12,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final imageUrl = photo['image'] as String? ?? '';
                final caption = photo['caption'] as String? ?? '';

                return GestureDetector(
                  onTap: () => _showPhotoDetail(photo, isDark),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: Environment.fixMediaUrl(imageUrl),
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 140,
                            height: 140,
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 140,
                            height: 140,
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                        // Caption overlay
                        if (caption.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                ),
                              ),
                              child: Text(
                                caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    // Ask for caption
    String? caption;
    if (mounted) {
      caption = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final captionCtrl = TextEditingController();
          return AlertDialog(
            title: const Text('Add a caption'),
            content: TextField(
              controller: captionCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Optional caption...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Skip'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    }

    if (caption == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      await ApiService().uploadEventPhoto(
        _event.id,
        File(image.path),
        caption: caption,
      );
      await _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded!'), backgroundColor: AppColors.burundiGreen),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo'), backgroundColor: AppColors.burundiRed),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoDetail(Map<String, dynamic> photo, bool isDark) {
    final imageUrl = photo['image'] as String? ?? '';
    final caption = photo['caption'] as String? ?? '';
    final uploaderName = photo['uploaded_by_name'] as String? ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(imageUrl),
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
                errorWidget: (_, _, _) => const SizedBox(
                  height: 300,
                  child: Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                ),
              ),
            ),
            if (caption.isNotEmpty || uploaderName.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    if (uploaderName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'By $uploaderName',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Attendees Section ─────────────────────────────────

  Widget _buildAttendeesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, color: AppColors.burundiGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Attendees',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
            const SizedBox(width: 8),
            if (!_loadingAttendees)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_attendees.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.burundiGreen,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingAttendees)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_attendees.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No attendees yet',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attendees.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final attendee = _attendees[index];
                final name = attendee['name'] as String? ?? 'User';
                final badgeType = attendee['badge_type'] as String?;
                final nationality = attendee['nationality'] as String? ?? '';

                return SizedBox(
                  width: 70,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.15),
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.burundiGreen,
                              ),
                            ),
                          ),
                          if (badgeType != null && badgeType.isNotEmpty)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Icon(
                                Icons.verified,
                                size: 14,
                                color: badgeType == 'GOLD' ? const Color(0xFFD4AF37) : Colors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.split(' ').first,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.lightText,
                        ),
                      ),
                      if (nationality.isNotEmpty)
                        Text(
                          nationality,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  static const List<String> _countryList = [
    'Afghanistan', 'Albania', 'Algeria', 'Angola', 'Argentina', 'Australia',
    'Austria', 'Bangladesh', 'Belgium', 'Benin', 'Botswana', 'Brazil',
    'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cameroon', 'Canada',
    'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia',
    'Comoros', 'Congo (Brazzaville)', 'Congo (DRC)', 'Côte d\'Ivoire',
    'Cuba', 'Denmark', 'Djibouti', 'Egypt', 'Equatorial Guinea', 'Eritrea',
    'Eswatini', 'Ethiopia', 'Finland', 'France', 'Gabon', 'Gambia',
    'Germany', 'Ghana', 'Greece', 'Guinea', 'Guinea-Bissau', 'India',
    'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica',
    'Japan', 'Jordan', 'Kenya', 'Korea (South)', 'Kuwait', 'Lebanon',
    'Lesotho', 'Liberia', 'Libya', 'Madagascar', 'Malawi', 'Malaysia',
    'Mali', 'Mauritania', 'Mauritius', 'Mexico', 'Morocco', 'Mozambique',
    'Namibia', 'Netherlands', 'New Zealand', 'Niger', 'Nigeria', 'Norway',
    'Pakistan', 'Palestine', 'Peru', 'Philippines', 'Poland', 'Portugal',
    'Qatar', 'Romania', 'Russia', 'Rwanda', 'São Tomé and Príncipe',
    'Saudi Arabia', 'Senegal', 'Seychelles', 'Sierra Leone', 'Somalia',
    'South Africa', 'South Sudan', 'Spain', 'Sudan', 'Sweden',
    'Switzerland', 'Tanzania', 'Thailand', 'Togo', 'Tunisia', 'Turkey',
    'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom',
    'United States', 'Venezuela', 'Vietnam', 'Zambia', 'Zimbabwe',
  ];
}

/// Decorative corner ornament for the greeting postcard
class _CornerOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // L-shaped corner bracket
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.7, 0);
    canvas.drawPath(path, paint);

    // Small diamond accent
    final diamondPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final dp = Path()
      ..moveTo(size.width * 0.15, 0)
      ..lineTo(size.width * 0.22, size.height * 0.07)
      ..lineTo(size.width * 0.15, size.height * 0.14)
      ..lineTo(size.width * 0.08, size.height * 0.07)
      ..close();
    canvas.drawPath(dp, diamondPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
