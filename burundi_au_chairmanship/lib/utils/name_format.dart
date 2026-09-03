/// Titles that must not be mistaken for someone's given name.
///
/// Verified accounts frequently carry them — "H.E. Évariste Ndayishimiye",
/// "Amb. Zeneb Kone" — and greeting those users "Good morning, H.E." reads
/// as a bug. Dots and case are stripped before matching, so "H.E.", "h.e"
/// and "HE" all land on `he`.
const _honorifics = {
  'he', 'se', 'excellency', 'excellence', 'his', 'her', 'son', 'their',
  'amb', 'ambassador', 'ambassadeur',
  'hon', 'honourable', 'honorable', 'rt', 'right',
  'dr', 'prof', 'professor', 'pr',
  'mr', 'mrs', 'ms', 'miss', 'mme', 'mlle', 'mgr', 'sir', 'madam', 'madame',
  'eng', 'ing', 'engr', 'arch',
  'sen', 'senator', 'mp', 'minister', 'ministre', 'president', 'président',
  'gen', 'maj', 'col', 'capt', 'lt', 'sgt', 'cdr',
  'rev', 'fr', 'pastor', 'imam', 'sheikh', 'sh',
};

String _normalise(String token) =>
    token.toLowerCase().replaceAll(RegExp(r'[.,]'), '').trim();

List<String> _tokens(String fullName) =>
    fullName.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Splits [fullName] into its leading titles and the actual name after them.
/// Returns the whole name as the "name" part when it is titles only.
({List<String> titles, List<String> name}) _split(String fullName) {
  final tokens = _tokens(fullName);
  var i = 0;
  while (i < tokens.length && _honorifics.contains(_normalise(tokens[i]))) {
    i++;
  }
  if (i == tokens.length) return (titles: const <String>[], name: tokens);
  return (titles: tokens.sublist(0, i), name: tokens.sublist(i));
}

class NameFormat {
  NameFormat._();

  /// How to address someone in a greeting.
  ///
  /// - `Évariste Ndayishimiye`      -> `Évariste`      (first name)
  /// - `H.E. Évariste Ndayishimiye` -> `H.E. Ndayishimiye` (title + surname)
  /// - `Amb. Kone`                  -> `Amb. Kone`
  ///
  /// A title is kept and paired with the family name, because addressing a
  /// dignitary by their first name is worse than not greeting them at all.
  /// [title] is the verified title stored on the account ("H.E.",
  /// "Ambassador"); it wins over any title already inside [fullName].
  static String greetingName(String? fullName, {String? title}) {
    final name = (fullName ?? '').trim();
    if (name.isEmpty) return '';
    final parts = _split(name);
    if (parts.name.isEmpty) return name;
    final verified = cleanTitle(title);
    final titles =
        verified.isNotEmpty ? verified : parts.titles.join(' ');
    if (titles.isEmpty) return parts.name.first;
    return '$titles ${parts.name.last}';
  }

  /// Drops the parenthetical gloss older records carry:
  /// `H.E. (His/Her Excellency)` -> `H.E.`
  static String cleanTitle(String? title) =>
      (title ?? '').split('(').first.trim();

  /// Avatar initials, skipping any titles: `H.E. Évariste Ndayishimiye` -> `ÉN`.
  static String initials(String? fullName, {String fallback = '?'}) {
    final name = (fullName ?? '').trim();
    if (name.isEmpty) return fallback;
    final parts = _split(name);
    final source = parts.name.isEmpty ? _tokens(name) : parts.name;
    final letters = source
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();
    return letters.isEmpty ? fallback : letters;
  }
}
