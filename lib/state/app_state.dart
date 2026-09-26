import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../models/resume.dart';

/// App-wide state: saved resumes, UI language and premium flag.
/// Persistence is local (SharedPreferences). See README for cloud sync notes.
class AppState extends ChangeNotifier {
  static const _kResumes = 'resumes_v1';
  static const _kLocale = 'locale_v1';
  static const _kPremium = 'premium_v1';

  SharedPreferences? _prefs;

  List<Resume> resumes = [];
  String locale = 'en';
  bool premium = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;

    final device = PlatformDispatcher.instance.locale.languageCode;
    locale = p.getString(_kLocale) ??
        (L10n.supported.contains(device) ? device : 'en');
    premium = p.getBool(_kPremium) ?? false;

    final raw = p.getString(_kResumes);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        resumes = list
            .map((e) => Resume.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        resumes = [];
      }
    }
    _sort();
  }

  Resume? byId(String id) {
    for (final r in resumes) {
      if (r.id == id) return r;
    }
    return null;
  }

  Resume createResume() {
    final r = Resume(lang: locale);
    resumes.insert(0, r);
    _persist();
    notifyListeners();
    return r;
  }

  Resume duplicate(Resume src) {
    final json = jsonDecode(jsonEncode(src.toJson())) as Map<String, dynamic>;
    json['id'] = newId();
    final copy = Resume.fromJson(json)..updatedAt = DateTime.now();
    resumes.insert(0, copy);
    _persist();
    notifyListeners();
    return copy;
  }

  void save(Resume r) {
    r.updatedAt = DateTime.now();
    if (byId(r.id) == null) resumes.insert(0, r);
    _sort();
    _persist();
    notifyListeners();
  }

  void delete(String id) {
    resumes.removeWhere((r) => r.id == id);
    _persist();
    notifyListeners();
  }

  void setLocale(String code) {
    locale = code;
    _prefs?.setString(_kLocale, code);
    notifyListeners();
  }

  /// Demo unlock. Replace with a real purchase flow (in_app_purchase /
  /// RevenueCat) before publishing to the stores.
  void setPremium(bool value) {
    premium = value;
    _prefs?.setBool(_kPremium, value);
    notifyListeners();
  }

  void _sort() => resumes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _persist() {
    _prefs?.setString(
      _kResumes,
      jsonEncode(resumes.map((r) => r.toJson()).toList()),
    );
  }
}
