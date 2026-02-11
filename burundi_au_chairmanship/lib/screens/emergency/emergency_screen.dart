import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/african_pattern.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<ApiEmergencyContact>? _contacts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final api = ApiService();
      final contacts = await api.getEmergencyContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Get contact by type from API data, or fall back to constants
  String _getNumber(String type) {
    if (_contacts != null) {
      final match = _contacts!.where((c) => c.type == type);
      if (match.isNotEmpty) return match.first.phoneNumber;
    }
    switch (type) {
      case 'embassy':
        return AppConstants.embassyNumber;
      case 'police':
        return AppConstants.policeNumber;
      case 'ambulance':
        return AppConstants.ambulanceNumber;
      case 'fire':
        return AppConstants.fireNumber;
      default:
        return AppConstants.emergencyNumber;
    }
  }

  String _getContactLabel(String type, AppLocalizations l10n) {
    if (_contacts != null) {
      final langCode = Localizations.localeOf(context).languageCode;
      final match = _contacts!.where((c) => c.type == type);
      if (match.isNotEmpty) return match.first.getName(langCode);
    }
    switch (type) {
      case 'embassy':
        return l10n.callEmbassy;
      case 'police':
        return l10n.callPolice;
      case 'ambulance':
        return l10n.callAmbulance;
      case 'fire':
        return l10n.callFire;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emergencySos),
        backgroundColor: AppColors.emergency,
      ),
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.emergencyLight,
              child: CustomPaint(
                painter: AfricanPatternPainter(
                  primaryColor: AppColors.emergency,
                  opacity: 0.05,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Main SOS Button
                  _buildSOSButton(l10n),
                  const SizedBox(height: 40),

                  // Emergency Contacts
                  Text(
                    l10n.emergencyContacts,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    // Contact Cards — from API
                    _buildEmergencyContactCard(
                      context,
                      icon: Icons.account_balance,
                      title: _getContactLabel('embassy', l10n),
                      subtitle: _getNumber('embassy'),
                      color: AppColors.burundiGreen,
                      onTap: () => _makePhoneCall(_getNumber('embassy')),
                    ),
                    const SizedBox(height: 12),

                    _buildEmergencyContactCard(
                      context,
                      icon: Icons.local_police,
                      title: _getContactLabel('police', l10n),
                      subtitle: _getNumber('police'),
                      color: AppColors.info,
                      onTap: () => _makePhoneCall(_getNumber('police')),
                    ),
                    const SizedBox(height: 12),

                    _buildEmergencyContactCard(
                      context,
                      icon: Icons.local_hospital,
                      title: _getContactLabel('ambulance', l10n),
                      subtitle: _getNumber('ambulance'),
                      color: AppColors.burundiRed,
                      onTap: () => _makePhoneCall(_getNumber('ambulance')),
                    ),
                    const SizedBox(height: 12),

                    _buildEmergencyContactCard(
                      context,
                      icon: Icons.local_fire_department,
                      title: _getContactLabel('fire', l10n),
                      subtitle: _getNumber('fire'),
                      color: AppColors.patternOrange,
                      onTap: () => _makePhoneCall(_getNumber('fire')),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Share Location Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _shareLocation,
                      icon: const Icon(Icons.share_location),
                      label: Text(l10n.shareLocation),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergency,
                        side: const BorderSide(color: AppColors.emergency, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Safety Tips
                  _buildSafetyTips(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(AppLocalizations l10n) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _showSOSConfirmation(context),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emergency,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergency.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: Colors.white, size: 60),
                  SizedBox(height: 8),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.tapForHelp,
          style: TextStyle(
            color: AppColors.emergency.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.call, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyTips(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Safety Tips',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('Stay calm and assess the situation'),
          _buildTip('Move to a safe location if possible'),
          _buildTip('Share your location with trusted contacts'),
          _buildTip('Follow instructions from emergency services'),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(tip)),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location sharing feature coming soon'),
        backgroundColor: AppColors.burundiGreen,
      ),
    );
  }

  void _showSOSConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Emergency Call'),
          ],
        ),
        content: const Text(
          'This will call the Burundi Embassy emergency line. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(_getNumber('embassy'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }
}
