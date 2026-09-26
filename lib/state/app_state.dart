import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../models/resume.dart';
import '../services/ai_service.dart';

/// Compile-time configuration, set with `--dart-define`:
///   flutter build web --dart-define=AI_ENDPOINT=https://your-worker.example.com/ai
const String kAiEndpoint = String.fromEnvironment('AI_ENDPOINT');
const String kAiToken = String.fromEnvironment('AI_TOKEN');

/// App-wide state: saved resumes, UI language, premium flag and AI settings.
/// Persistence is local (SharedPreferences). See README for cloud sync notes.
class AppState extends ChangeNotifier {
  static const _kResumes = 'resumes_v1';
  static const _kLocale = 'locale_v1';
  static const _kPremium = 'premium_v1';
  static const _kAiEndpoint = 'ai_endpoint_v1';
  static const _kAiDay = 'ai_day_v1';
  static const _kAiCount = 'ai_count_v1';

  /// Free (non-premium) AI requests per day when a remote AI server is used.
  /// This limit is enforced on the device only. Enforce it on your server too.
  static const freeDailyAi = 5;

  SharedPreferences? _prefs;

  List<Resume> resumes = [];
  String locale = 'en';
  bool premium = false;

  /// False until the user has picked a language on first launch.
  bool onboarded = false;

  String _aiEndpointOverride = '';
  String _aiDay = '';
  int _aiCount = 0;

  AiService? _ai;
  String _aiFor = '\u0000';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;

    final saved = p.getString(_kLocale);
    if (saved != null && L10n.supported.contains(saved)) {
      locale = saved;
      onboarded = true;
    } else {
      final device = PlatformDispatcher.instance.locale;
      locale = L10n.matchDevice(device.languageCode, device.countryCode);
      onboarded = false;
    }

    premium = p.getBool(_kPremium) ?? false;
    _aiEndpointOverride = p.getString(_kAiEndpoint) ?? '';
    _aiDay = p.getString(_kAiDay) ?? '';
    _aiCount = p.getInt(_kAiCount) ?? 0;

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

  // ------------------------------------------------------------------ resumes

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

  // ----------------------------------------------------------------- settings

  void setLocale(String code) {
    locale = code;
    _prefs?.setString(_kLocale, code);
    notifyListeners();
  }

  /// Called when the user confirms a language on first launch.
  void completeOnboarding() {
    onboarded = true;
    _prefs?.setString(_kLocale, locale);
    notifyListeners();
  }

  /// Demo unlock. Replace with a real purchase flow (in_app_purchase /
  /// RevenueCat) before publishing to the stores. See docs/MONETIZATION.md.
  void setPremium(bool value) {
    premium = value;
    _prefs?.setBool(_kPremium, value);
    notifyListeners();
  }

  // ----------------------------------------------------------------------- AI

  /// User-entered endpoint (Settings) wins over the compile-time default.
  String get aiEndpointOverride => _aiEndpointOverride;

  String get aiEndpoint =>
      _aiEndpointOverride.trim().isNotEmpty ? _aiEndpointOverride.trim() : kAiEndpoint;

  void setAiEndpoint(String value) {
    _aiEndpointOverride = value.trim();
    _prefs?.setString(_kAiEndpoint, _aiEndpointOverride);
    notifyListeners();
  }

  AiService get ai {
    final ep = aiEndpoint;
    if (_ai == null || _aiFor != ep) {
      _ai = AiService(endpoint: ep, token: kAiToken);
      _aiFor = ep;
    }
    return _ai!;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int get aiLeft {
    if (premium) return 999;
    final used = _aiDay == _today() ? _aiCount : 0;
    final left = freeDailyAi - used;
    return left < 0 ? 0 : left;
  }

  /// Uses one remote AI request. Returns false when the daily limit is spent.
  bool tryConsumeAi() {
    if (premium) return true;
    final today = _today();
    if (_aiDay != today) {
      _aiDay = today;
      _aiCount = 0;
    }
    if (_aiCount >= freeDailyAi) return false;
    _aiCount++;
    _persistAi();
    notifyListeners();
    return true;
  }

  /// Gives a request back when the call failed.
  void refundAi() {
    if (premium) return;
    if (_aiDay == _today() && _aiCount > 0) {
      _aiCount--;
      _persistAi();
      notifyListeners();
    }
  }

  void _persistAi() {
    _prefs?.setString(_kAiDay, _aiDay);
    _prefs?.setInt(_kAiCount, _aiCount);
  }

  // ------------------------------------------------------------------ helpers

  void _sort() => resumes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _persist() {
    _prefs?.setString(
      _kResumes,
      jsonEncode(resumes.map((r) => r.toJson()).toList()),
    );
  }
}
