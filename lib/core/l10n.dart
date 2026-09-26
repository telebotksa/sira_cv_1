import 'dart:ui' show Locale;

import 'strings/ar.dart';
import 'strings/de.dart';
import 'strings/en.dart';
import 'strings/es.dart';
import 'strings/es_mx.dart';
import 'strings/fr.dart';
import 'strings/hi.dart';
import 'strings/id.dart';
import 'strings/it.dart';
import 'strings/nb.dart';
import 'strings/nl.dart';
import 'strings/pl.dart';
import 'strings/pt.dart';
import 'strings/pt_br.dart';
import 'strings/ro.dart';
import 'strings/tr.dart';
import 'strings/vi.dart';
import 'strings/zh.dart';

/// Built-in localization (no code generation). Used for the app UI and for
/// section headings and text inside the exported CV.
///
/// Translation files in `strings/` are generated; every language contains the
/// same set of keys.
class L10n {
  /// Language codes. `es_MX` and `pt_BR` are regional variants.
  static const supported = [
    'ar',
    'en',
    'hi',
    'zh',
    'es',
    'es_MX',
    'id',
    'de',
    'fr',
    'it',
    'nl',
    'nb',
    'pl',
    'pt',
    'pt_BR',
    'ro',
    'tr',
    'vi',
  ];

  /// Native names shown in the language picker.
  static const names = {
    'ar': 'العربية',
    'en': 'English',
    'hi': 'हिन्दी',
    'zh': '简体中文',
    'es': 'Español (España)',
    'es_MX': 'Español (México)',
    'id': 'Bahasa Indonesia',
    'de': 'Deutsch',
    'fr': 'Français',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'nb': 'Norsk (bokmål)',
    'pl': 'Polski',
    'pt': 'Português (Portugal)',
    'pt_BR': 'Português (Brasil)',
    'ro': 'Română',
    'tr': 'Türkçe',
    'vi': 'Tiếng Việt',
  };

  static const Map<String, Map<String, String>> _data = {
    'ar': stringsAr,
    'en': stringsEn,
    'hi': stringsHi,
    'zh': stringsZh,
    'es': stringsEs,
    'es_MX': stringsEsMx,
    'id': stringsId,
    'de': stringsDe,
    'fr': stringsFr,
    'it': stringsIt,
    'nl': stringsNl,
    'nb': stringsNb,
    'pl': stringsPl,
    'pt': stringsPt,
    'pt_BR': stringsPtBr,
    'ro': stringsRo,
    'tr': stringsTr,
    'vi': stringsVi,
  };

  static bool isRtl(String code) => code == 'ar';

  /// Flutter [Locale] for a language code such as `pt_BR`.
  static Locale localeOf(String code) {
    final parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  /// Picks the best supported code for a device locale, or `en`.
  static String matchDevice(String languageCode, String? countryCode) {
    final full = countryCode == null || countryCode.isEmpty
        ? languageCode
        : '${languageCode}_$countryCode';
    if (supported.contains(full)) return full;
    if (languageCode == 'no' || languageCode == 'nn') return 'nb';
    if (languageCode == 'in') return 'id'; // legacy Android code
    if (supported.contains(languageCode)) return languageCode;
    return 'en';
  }

  static String t(String code, String key) =>
      _data[code]?[key] ?? stringsEn[key] ?? key;

  /// Replaces `{name}` style placeholders.
  static String fill(String template, Map<String, String> values) {
    var out = template;
    values.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }
}
