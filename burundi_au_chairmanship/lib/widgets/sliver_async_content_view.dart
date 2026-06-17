import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'async_content_view.dart';
import 'shimmer_loading.dart';

/// Sliver-compatible version of [AsyncContentView] for use inside
/// [CustomScrollView]. Wraps loading / error / empty states in
/// [SliverFillRemaining] so they fill the viewport.
class SliverAsyncContentView extends StatelessWidget {
  final AsyncContentState state;
  final Widget child;

  // Loading
  final Widget? loadingWidget;

  // Error
  final IconData errorIcon;
  final String? errorMessage;
  final String? errorSubtitle;

  // Empty
  final IconData emptyIcon;
  final String? emptyMessage;
  final String? emptySubtitle;

  // Actions
  final VoidCallback? onRetry;

  const SliverAsyncContentView({
    super.key,
    required this.state,
    required this.child,
    this.loadingWidget,
    this.errorIcon = Icons.cloud_off_rounded,
    this.errorMessage,
    this.errorSubtitle,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyMessage,
    this.emptySubtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case AsyncContentState.loading:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: loadingWidget ?? const ShimmerGenericCardSkeleton(),
        );
      case AsyncContentState.error:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildMessageState(
            context,
            icon: errorIcon,
            title: errorMessage ?? AppLocalizations.of(context).errorLoadingContent,
            subtitle: errorSubtitle ?? AppLocalizations.of(context).errorLoadingSubtitle,
            showRetry: true,
          ),
        );
      case AsyncContentState.empty:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildMessageState(
            context,
            icon: emptyIcon,
            title: emptyMessage ?? AppLocalizations.of(context).noData,
            subtitle: emptySubtitle,
            showRetry: false,
          ),
        );
      case AsyncContentState.content:
        return child;
    }
  }

  Widget _buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool showRetry,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(AppLocalizations.of(context).retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
