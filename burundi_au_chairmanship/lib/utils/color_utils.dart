import 'dart:ui';

/// Parse hex color string like "#409843" into a [Color].
Color hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.isEmpty) return const Color(0xFF409843);
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return const Color(0xFF409843);
  return Color(parsed);
}
