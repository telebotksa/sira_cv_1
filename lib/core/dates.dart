import 'package:intl/intl.dart';

/// Dates are stored as `yyyy-MM` (month precision). Older free-text values
/// that do not match are displayed as they were typed.
class Dates {
  static final _iso = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$');

  static DateTime? parse(String s) {
    final m = _iso.firstMatch(s.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    if (mo < 1 || mo > 12) return null;
    return DateTime(y, mo, 1);
  }

  static String toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Localized "Mar 2021" style text. Digits are always Western (0-9),
  /// which is what recruiters expect on a CV.
  static String format(String stored, String lang) {
    final d = parse(stored);
    if (d == null) return stored.trim();
    try {
      return westernDigits(DateFormat.yMMM(lang).format(d));
    } catch (_) {
      return toIso(d);
    }
  }

  static String westernDigits(String s) {
    final b = StringBuffer();
    for (final c in s.runes) {
      if (c >= 0x0660 && c <= 0x0669) {
        b.writeCharCode(0x30 + c - 0x0660);
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        b.writeCharCode(0x30 + c - 0x06F0);
      } else if (c >= 0x0966 && c <= 0x096F) {
        b.writeCharCode(0x30 + c - 0x0966);
      } else {
        b.writeCharCode(c);
      }
    }
    return b.toString();
  }
}
