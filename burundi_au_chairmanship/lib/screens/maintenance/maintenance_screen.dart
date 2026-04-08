import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';

class MaintenanceScreen extends StatefulWidget {
  final Map<String, dynamic>? maintenanceData;

  const MaintenanceScreen({super.key, this.maintenanceData});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getTitle(bool isFrench) {
    final data = widget.maintenanceData?['active'];
    if (data != null) {
      final title = isFrench
          ? (data['title_fr'] ?? data['title'] ?? '')
          : (data['title'] ?? '');
      if (title.isNotEmpty) return title;
    }
    return isFrench ? 'Maintenance en cours' : 'Under Maintenance';
  }

  String _getDescription(bool isFrench) {
    final data = widget.maintenanceData?['active'];
    if (data != null) {
      final desc = isFrench
          ? (data['description_fr'] ?? data['description'] ?? '')
          : (data['description'] ?? '');
      if (desc.isNotEmpty) return desc;
    }
    return isFrench
        ? 'Nous effectuons une maintenance planifiée. Veuillez réessayer bientôt.'
        : 'We are performing scheduled maintenance. Please try again shortly.';
  }

  String? _getEstimatedEnd() {
    final data = widget.maintenanceData?['active'];
    if (data != null && data['ends_at'] != null) {
      try {
        final endsAt = DateTime.parse(data['ends_at']);
        final now = DateTime.now();
        final diff = endsAt.difference(now);
        if (diff.isNegative) return null;
        if (diff.inHours > 0) {
          return '~${diff.inHours}h ${diff.inMinutes % 60}m';
        }
        return '~${diff.inMinutes}m';
      } catch (_) {}
    }
    return null;
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] != true) {
        Navigator.of(context).pushReplacementNamed('/auth');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Still under maintenance. Please try again later.'),
            backgroundColor: AppColors.burundiRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFrench = context.watch<LanguageProvider>().isFrench;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estimatedEnd = _getEstimatedEnd();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Animated maintenance icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.build_circle_outlined,
                      size: 60,
                      color: AppColors.burundiGreen,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  _getTitle(isFrench),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  _getDescription(isFrench),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                // Estimated time
                if (estimatedEnd != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.auGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.auGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: AppColors.auGold,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isFrench
                              ? 'Temps estimé: $estimatedEnd'
                              : 'Estimated time: $estimatedEnd',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _retry,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isRetrying
                          ? (isFrench ? 'Vérification...' : 'Checking...')
                          : (isFrench ? 'Réessayer' : 'Retry'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Footer
                Text(
                  'Burundi AU Chairmanship 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white30
                        : AppColors.lightTextSecondary.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
