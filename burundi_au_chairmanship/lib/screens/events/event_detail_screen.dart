import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/event_registration_model.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
                  _buildCountdownSection(context, isDark),
                  const SizedBox(height: 20),

                  // Event info card
                  _buildEventInfoCard(context, langCode, isDark),
                  const SizedBox(height: 20),

                  // Registration section
                  _buildRegistrationSection(context, langCode, isDark),

                  // Proxy registration
                  if (_event.allowProxyRegistration && _event.isRegistrationOpen && !_event.isEventPast)
                    _buildProxySection(context, langCode, isDark),

                  // Contact section
                  if (_event.contactEmail.isNotEmpty || _event.contactPhone.isNotEmpty)
                    _buildContactSection(context, isDark),

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

  // ── Countdown Section ─────────────────────────────────────

  Widget _buildCountdownSection(BuildContext context, bool isDark) {
    if (_event.eventDate == null) return const SizedBox.shrink();

    final isPast = _event.isEventPast;

    if (isPast) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Event Ended',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_timeLeft == null) return const SizedBox.shrink();

    final days = _timeLeft!.inDays;
    final hours = _timeLeft!.inHours % 24;
    final minutes = _timeLeft!.inMinutes % 60;
    final seconds = _timeLeft!.inSeconds % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Event Starts In',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _countdownBox('$days', 'Days'),
              _countdownDivider(),
              _countdownBox(hours.toString().padLeft(2, '0'), 'Hours'),
              _countdownDivider(),
              _countdownBox(minutes.toString().padLeft(2, '0'), 'Min'),
              _countdownDivider(),
              _countdownBox(seconds.toString().padLeft(2, '0'), 'Sec'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _countdownDivider() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Event Info Card ───────────────────────────────────────

  Widget _buildEventInfoCard(BuildContext context, String langCode, bool isDark) {
    final description = _event.getDescription(langCode);
    final venue = _event.getVenue(langCode);

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
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Date
          if (_event.eventDate != null)
            _infoRow(
              Icons.calendar_today,
              _formatFullDate(_event.eventDate!),
              isDark,
            ),

          // End date
          if (_event.eventEndDate != null) ...[
            const SizedBox(height: 10),
            _infoRow(
              Icons.event_available,
              'Until ${_formatFullDate(_event.eventEndDate!)}',
              isDark,
            ),
          ],

          // Venue
          if (venue.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow(Icons.location_on, venue, isDark),
          ],

          // Directions button
          if (_event.venueAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Get Directions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burundiGreen,
                  side: const BorderSide(color: AppColors.burundiGreen),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.burundiGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ── Registration Section ──────────────────────────────────

  Widget _buildRegistrationSection(BuildContext context, String langCode, bool isDark) {
    // Already registered
    if (_event.hasRegistered) {
      return _buildRegisteredConfirmation(langCode, isDark);
    }

    // Registration closed or event past
    if (!_event.isRegistrationOpen || _event.isEventPast) {
      return _buildRegistrationClosed(isDark);
    }

    // Registration not enabled
    if (!_event.isRegistrationEnabled) {
      return const SizedBox.shrink();
    }

    // Show registration form
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
              fontSize: 20,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                  const SizedBox(height: 4),
                  ...options.map((option) {
                    final selected = _formValues[field.fieldName] == option;
                    return InkWell(
                      onTap: () {
                        setState(() => _formValues[field.fieldName] = option);
                        state.didChange(option);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? AppColors.burundiGreen : (isDark ? Colors.white38 : Colors.black38),
                                  width: selected ? 2 : 1.5,
                                ),
                              ),
                              child: selected
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.burundiGreen,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(option, style: TextStyle(fontSize: 14, color: textColor))),
                          ],
                        ),
                      ),
                    );
                  }),
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
                  const SizedBox(height: 4),
                  ...options.map((option) {
                    final isChecked = selected.contains(option);
                    return CheckboxListTile(
                      title: Text(option, style: TextStyle(fontSize: 14, color: textColor)),
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          final list = List<String>.from(selected);
                          if (val == true) {
                            list.add(option);
                          } else {
                            list.remove(option);
                          }
                          _formValues[field.fieldName] = list;
                        });
                        state.didChange(_formValues[field.fieldName] as List<String>);
                      },
                      activeColor: AppColors.burundiGreen,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
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

  // ── Actions ───────────────────────────────────────────────

  void _openDirections() {
    final address = Uri.encodeComponent(_event.venueAddress);
    launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$address'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _submitRegistration(String langCode) async {
    if (!_formKey.currentState!.validate()) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: AppColors.burundiGreen,
        ),
      );
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Try again.'), backgroundColor: AppColors.burundiRed),
      );
    }
  }

  Future<void> _submitProxyRegistration() async {
    if (!_proxyFormKey.currentState!.validate()) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proxy registration submitted!'),
          backgroundColor: AppColors.burundiGreen,
        ),
      );
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
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
