import 'package:flutter_test/flutter_test.dart';
import 'package:burundi_au_chairmanship/utils/name_format.dart';

void main() {
  test('plain names greet by first name', () {
    expect(NameFormat.greetingName('Évariste Ndayishimiye'), 'Évariste');
    expect(NameFormat.greetingName('Eva'), 'Eva');
    expect(NameFormat.greetingName('  '), '');
    expect(NameFormat.greetingName(null), '');
  });

  test('titles are kept and paired with the family name', () {
    expect(NameFormat.greetingName('H.E. Évariste Ndayishimiye'),
        'H.E. Ndayishimiye');
    expect(NameFormat.greetingName('Amb. Zeneb Kone'), 'Amb. Kone');
    expect(NameFormat.greetingName('Rt. Hon. Alice Nkurunziza'),
        'Rt. Hon. Nkurunziza');
    expect(NameFormat.greetingName('Dr Jean'), 'Dr Jean');
  });

  test('a name made only of titles is left alone', () {
    expect(NameFormat.greetingName('H.E.'), 'H.E.');
  });

  _verifiedTitles();

  test('initials skip titles', () {
    expect(NameFormat.initials('H.E. Évariste Ndayishimiye'), 'ÉN');
    expect(NameFormat.initials('Eva'), 'E');
    expect(NameFormat.initials(''), '?');
    expect(NameFormat.initials('H.E.'), 'H');
  });
}

// Verified accounts: the title comes from the verification record and older
// ones carry a parenthetical gloss.
void _verifiedTitles() {
  test('verified title wins and loses its gloss', () {
    expect(
        NameFormat.greetingName('Évariste Ndayishimiye',
            title: 'H.E. (His/Her Excellency)'),
        'H.E. Ndayishimiye');
    expect(NameFormat.greetingName('Zeneb Kone', title: 'Ambassador'),
        'Ambassador Kone');
    expect(NameFormat.greetingName('Eva Nkuru', title: ''), 'Eva');
    expect(NameFormat.cleanTitle('H.E. (His/Her Excellency)'), 'H.E.');
  });
}
