import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'verified_badge.dart';

/// Shows a success dialog when verification request is approved
Future<void> showVerificationApprovedDialog(
  BuildContext context, {
  required String badgeType,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.burundiGreen,
              ),
            ),
            const SizedBox(height: 24),

            // Badge display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                VerifiedBadge(badgeType: badgeType, size: 28),
              ],
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              'Your verification request has been approved!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),

            // Badge type info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: badgeType == 'GOLD'
                    ? const Color(0xFFFFD700).withValues(alpha: 0.1)
                    : const Color(0xFF409843).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VerifiedBadge(badgeType: badgeType, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    badgeType == 'GOLD'
                        ? 'Gold Badge Verified'
                        : 'Blue Badge Verified',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: badgeType == 'GOLD'
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF409843),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Shows a dialog when verification request is rejected
Future<bool?> showVerificationRejectedDialog(
  BuildContext context, {
  required String reason,
  required VoidCallback onAppeal,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burundiRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                size: 64,
                color: AppColors.burundiRed,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Verification Not Approved',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              'We\'re sorry, but your verification request was not approved at this time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Reason box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.burundiRed.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.burundiRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reason:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appeal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true); // Return true to indicate appeal
                  onAppeal();
                },
                icon: const Icon(Icons.edit_note),
                label: const Text(
                  'Submit an Appeal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Close button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                  side: BorderSide(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Shows appeal submission dialog
Future<void> showAppealDialog(
  BuildContext context, {
  required Function(String) onSubmit,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.burundiGreen),
            const SizedBox(width: 12),
            Text(
              'Submit an Appeal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If you believe your request was rejected in error, please explain why you should be verified:',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Explain why you believe this is an error...',
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.burundiGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for your appeal';
                  }
                  if (value.trim().length < 20) {
                    return 'Please provide more details (at least 20 characters)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
              side: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                onSubmit(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Appeal'),
          ),
        ],
      );
    },
  );
}
