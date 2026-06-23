import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../services/api_service.dart';

Future<void> showSupportOptionsModal(BuildContext context, {String? prefilledSubject}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final langCode = context.read<LanguageProvider>().languageCode;

  bool liveAgentOnline = false;
  try {
    final settings = await ApiService().getSettings();
    if (settings != null) {
      liveAgentOnline = settings.liveAgentOnline;
    }
  } catch (_) {}

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              langCode == 'fr' ? 'Comment souhaitez-vous nous contacter ?' : 'How would you like to reach us?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Email Support
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.email_rounded, color: AppColors.burundiGreen, size: 28),
              ),
              title: Text(
                langCode == 'fr' ? 'Ticket de support' : 'Support Ticket',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: Text(langCode == 'fr' ? 'Créez un ticket, nous répondons sous 24 heures' : 'Create a ticket, we respond within 24 hours'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                if (prefilledSubject != null) {
                  Navigator.pushNamed(context, '/contact-support', arguments: prefilledSubject);
                } else {
                  Navigator.pushNamed(context, '/support-tickets');
                }
              },
            ),
            const SizedBox(height: 8),

            // Live Agent
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: liveAgentOnline
                      ? AppColors.burundiGreen.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: liveAgentOnline ? AppColors.burundiGreen : Colors.grey,
                  size: 28,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    langCode == 'fr' ? 'Agent en direct' : 'Live Agent',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: liveAgentOnline
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: liveAgentOnline ? Colors.green : Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      liveAgentOnline
                          ? (langCode == 'fr' ? 'EN LIGNE' : 'ONLINE')
                          : (langCode == 'fr' ? 'HORS LIGNE' : 'OFFLINE'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                liveAgentOnline
                    ? (langCode == 'fr' ? 'Réponse rapide via le chat support' : 'Quick response via support chat')
                    : (langCode == 'fr' ? 'Aucun agent disponible pour le moment' : 'No agents available right now'),
                style: TextStyle(color: liveAgentOnline ? null : Colors.grey),
              ),
              trailing: liveAgentOnline ? const Icon(Icons.chevron_right) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              enabled: liveAgentOnline,
              onTap: liveAgentOnline
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        final api = ApiService();
                        final result = await api.createTicket(
                          'Live Chat Support',
                          'Started a live chat session.',
                        );
                        if (context.mounted) {
                          Navigator.pushNamed(
                            context,
                            '/ticket-conversation',
                            arguments: result['id'],
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to start live chat: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
