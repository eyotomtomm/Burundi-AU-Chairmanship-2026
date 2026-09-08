import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AppLocalizations.translate(key)` returns the key itself when it is missing,
/// so a key that never reached the ARB files renders on screen as literal
/// "w_report_post". That failed silently across 613 keys once; these tests are
/// the tripwire.
void main() {
  final root = Directory.current;
  final en = _arbKeys(File('${root.path}/lib/l10n/app_en.arb'));
  final fr = _arbKeys(File('${root.path}/lib/l10n/app_fr.arb'));

  test('every translate() key has an English string', () {
    final missing = <String, Set<String>>{};
    _usedKeys(root).forEach((key, files) {
      // Dynamically built keys (translate('x_$status')) cannot be checked here;
      // the concrete keys they resolve to are asserted below.
      if (key.contains(r'$')) return;
      if (!en.contains(key)) missing[key] = files;
    });
    expect(missing, isEmpty,
        reason: 'These keys would render as raw text:\n'
            '${missing.entries.map((e) => '  ${e.key}  <- ${e.value.join(', ')}').join('\n')}');
  });

  test('English and French carry the same keys', () {
    expect(en.difference(fr), isEmpty, reason: 'missing from app_fr.arb');
    expect(fr.difference(en), isEmpty, reason: 'missing from app_en.arb');
  });

  test('the dynamic support-status keys all exist', () {
    for (final status in ['open', 'in_progress', 'resolved', 'closed']) {
      expect(en, contains('sup_status_$status'));
    }
  });

  test('the translate() lookup table covers the ARB', () {
    // AppLocalizations builds its own key -> getter map by hand; a key present
    // in the ARB but absent there is just as invisible to translate().
    final source = File('${root.path}/lib/l10n/app_localizations.dart').readAsStringSync();
    final mapped = RegExp(r"^\s*'([a-z0-9_]+)':", multiLine: true)
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    // A few entries are aliased — 'continue' maps to g.continueText because
    // `continue` is a Dart keyword — so count the getter side too.
    final getters = RegExp(r'\bg\.([A-Za-z0-9_]+)')
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    expect(en.difference(mapped).difference(getters), isEmpty,
        reason: 'in the ARB but not in AppLocalizations._buildCache');
  });
}

Set<String> _arbKeys(File file) {
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return data.keys.where((k) => !k.startsWith('@')).toSet();
}

/// String literals that sit inside a `translate(...)` call but are comparison
/// values rather than keys, e.g. `translate(badge == 'GOLD' ? a : b)`.
const _notKeys = {'GOLD', 'BLUE', 'GREEN', 'hint', 'label', 'denied', 'value'};

/// Every `translate(...)` key in lib/, mapped to the files using it.
///
/// Matches the whole argument list rather than a literal glued to the paren,
/// because keys are routinely chosen inline:
/// `translate(pending ? 'more_verif_pending' : 'more_verif_in_review')`.
/// A tighter pattern missed 64 keys, which then rendered as raw text on screen.
Map<String, Set<String>> _usedKeys(Directory root) {
  final call = RegExp(r"\.translate\(([^;]{0,200}?)\)", dotAll: true);
  final literal = RegExp(r"'([A-Za-z][A-Za-z0-9_]{2,})'");
  final out = <String, Set<String>>{};
  for (final entry in Directory('${root.path}/lib').listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.dart')) continue;
    if (entry.path.contains('/l10n/')) continue;
    for (final m in call.allMatches(entry.readAsStringSync())) {
      for (final k in literal.allMatches(m.group(1)!)) {
        final key = k.group(1)!;
        if (_notKeys.contains(key)) continue;
        out.putIfAbsent(key, () => <String>{}).add(entry.uri.pathSegments.last);
      }
    }
  }
  return out;
}
