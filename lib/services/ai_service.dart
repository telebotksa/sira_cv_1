import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/l10n.dart';
import '../models/resume.dart';
import 'suggestions.dart';

enum AiTask {
  summary,
  improve,
  bullets,
  skills,
  translate,
  jobMatch,
  coverLetter,
  review,
}

class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AiResult {
  const AiResult(this.text, {this.local = false});

  final String text;

  /// True when produced by the built-in offline logic instead of the server.
  final bool local;

  List<String> get lines => text
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'^\s*(?:[-•·*]+|\d+[.)])\s*'), '').trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// AI layer. With an [endpoint] it calls your own server (which holds the model
/// API key; never put a key in the app). Without one it falls back to basic
/// offline logic so every screen still works.
///
/// Server contract (see backend/README.md):
///   POST {endpoint}  JSON: {task, lang, target, input, job, resume}
///   200 JSON: {"text": "..."}
class AiService {
  AiService({required this.endpoint, this.token = '', http.Client? client})
      : _client = client ?? http.Client();

  final String endpoint;
  final String token;
  final http.Client _client;

  bool get isRemote => endpoint.trim().isNotEmpty;

  Future<AiResult> run(
    AiTask task,
    Resume r, {
    String input = '',
    String target = '',
    String job = '',
  }) async {
    if (isRemote) {
      return _remote(task, r, input: input, target: target, job: job);
    }
    return _local(task, r, input: input, job: job);
  }

  // ------------------------------------------------------------------ remote

  Future<AiResult> _remote(
    AiTask task,
    Resume r, {
    required String input,
    required String target,
    required String job,
  }) async {
    final body = jsonEncode({
      'task': task.name,
      'lang': r.lang,
      'target': target.isEmpty ? Suggestions.detectLang(r) : target,
      'input': input,
      'job': job,
      'resume': compact(r),
    });

    try {
      final res = await _client
          .post(
            Uri.parse(endpoint.trim()),
            headers: {
              'content-type': 'application/json',
              if (token.isNotEmpty) 'x-app-token': token,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) {
        throw AiException('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final text = data is Map ? (data['text'] as String?)?.trim() ?? '' : '';
      if (text.isEmpty) throw AiException('Empty response');
      return AiResult(text);
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException('Timeout');
    } catch (e) {
      throw AiException('$e');
    }
  }

  /// Compact resume sent to the server: only what the model needs.
  static Map<String, dynamic> compact(Resume r) => {
        'fullName': r.fullName,
        'jobTitle': r.jobTitle,
        'city': r.city,
        'summary': r.summary,
        'experiences': [
          for (final e in r.experiences)
            {
              'title': e.title,
              'company': e.company,
              'start': e.start,
              'end': e.current ? 'present' : e.end,
              'description': e.description,
            },
        ],
        'education': [
          for (final e in r.education)
            {'degree': e.degree, 'school': e.school, 'description': e.description},
        ],
        'skills': r.skills,
        'languages': [
          for (final l in r.languages) {'name': l.name, 'level': l.level},
        ],
        'projects': [
          for (final p in r.projects) {'name': p.name, 'description': p.description},
        ],
      };

  // ------------------------------------------------------------------- local

  AiResult _local(AiTask task, Resume r, {required String input, required String job}) {
    final lang = r.lang;
    switch (task) {
      case AiTask.summary:
        return AiResult(Suggestions.draftSummary(r), local: true);

      case AiTask.improve:
        return AiResult(_polish(input), local: true);

      case AiTask.bullets:
        final hint = L10n.t(lang, 'bulletHint');
        final verbs = Suggestions.actionVerbs(lang).take(5);
        return AiResult(verbs.map((v) => '$v … — $hint').join('\n'), local: true);

      case AiTask.skills:
        return AiResult(Suggestions.skillIdeas(r).take(20).join('\n'), local: true);

      case AiTask.translate:
        throw AiException(L10n.t(lang, 'aiTranslateNeedsServer'));

      case AiTask.jobMatch:
        return AiResult(_jobMatch(r, job), local: true);

      case AiTask.coverLetter:
        final skills = r.skills.isNotEmpty
            ? r.skills.take(4).join(', ')
            : L10n.t(lang, 'softSkills').split('|').take(3).join(', ');
        final title = r.jobTitle.trim().isEmpty
            ? L10n.t(lang, 'fallbackJob')
            : r.jobTitle.trim();
        return AiResult(
          L10n.fill(L10n.t(lang, 'clTemplate'), {
            'job': title,
            'skills': skills,
            'name': r.fullName.trim(),
          }),
          local: true,
        );

      case AiTask.review:
        return AiResult(_review(r), local: true);
    }
  }

  /// Light clean-up: spacing, capital first letter, closing punctuation.
  static String _polish(String text) {
    final out = <String>[];
    for (final raw in text.split('\n')) {
      var l = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (l.isEmpty) continue;
      l = l[0].toUpperCase() + l.substring(1);
      final last = l[l.length - 1];
      if (!'.!?؟。！？।'.contains(last)) l = '$l.';
      out.add(l);
    }
    return out.join('\n');
  }

  static final _wordSplit = RegExp(r'[^\p{L}\p{N}+#]+', unicode: true);

  static const _stop = {
    'the', 'and', 'for', 'with', 'you', 'our', 'are', 'will', 'have', 'this',
    'that', 'from', 'your', 'work', 'team', 'experience', 'years', 'ability',
    'strong', 'skills', 'must', 'able', 'all', 'can', 'who', 'including',
    'such', 'well', 'has', 'not', 'more', 'other', 'their', 'they', 'about',
    'into', 'over', 'also', 'within', 'across', 'role', 'job', 'position',
    'من', 'في', 'على', 'إلى', 'عن', 'مع', 'أو', 'التي', 'الذي', 'هذا', 'هذه',
    'أن', 'ان', 'لدى', 'كل', 'بين', 'ذلك', 'وفق',
  };

  String _resumeText(Resume r) => [
        r.jobTitle,
        r.summary,
        r.skills.join(' '),
        for (final e in r.experiences) '${e.title} ${e.company} ${e.description}',
        for (final e in r.education) '${e.degree} ${e.description}',
        for (final p in r.projects) '${p.name} ${p.description}',
      ].join(' ').toLowerCase();

  String _jobMatch(Resume r, String job) {
    final lang = r.lang;
    if (job.trim().isEmpty) throw AiException(L10n.t(lang, 'aiJobField'));

    final freq = <String, int>{};
    for (final w in job.toLowerCase().split(_wordSplit)) {
      if (w.length < 3 || _stop.contains(w) || RegExp(r'^\d+$').hasMatch(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final keywords = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    final top = keywords.take(25).toList();
    if (top.isEmpty) throw AiException(L10n.t(lang, 'aiJobField'));

    final text = _resumeText(r);
    final hit = top.where(text.contains).toList();
    final miss = top.where((k) => !text.contains(k)).toList();
    final pct = (hit.length * 100 / top.length).round();

    return '${L10n.t(lang, 'matchScore')}: $pct%\n\n'
        '${L10n.t(lang, 'matched')}: ${hit.isEmpty ? '-' : hit.join(', ')}\n\n'
        '${L10n.t(lang, 'missingKw')}: ${miss.isEmpty ? '-' : miss.join(', ')}';
  }

  String _review(Resume r) {
    final lang = r.lang;
    final c = Suggestions.completeness(r);
    final tips = <String>[];

    var score = c.score * 60;

    if (r.summary.trim().length >= 80) {
      score += 10;
    } else {
      tips.add(L10n.t(lang, 'rvSummaryShort'));
    }

    final descriptions = r.experiences.map((e) => e.description).join('\n');
    final bulletLines =
        descriptions.split('\n').where((l) => l.trim().isNotEmpty).length;
    if (bulletLines >= 3) {
      score += 10;
    } else {
      tips.add(L10n.t(lang, 'rvNoBullets'));
    }

    if (RegExp(r'\d').hasMatch(descriptions)) {
      score += 10;
    } else {
      tips.add(L10n.t(lang, 'rvNoNumbers'));
    }

    if (r.skills.length >= 6) {
      score += 10;
    } else {
      tips.add(L10n.t(lang, 'rvFewSkills'));
    }

    if (c.missing.isNotEmpty) {
      tips.add('${L10n.t(lang, 'missing')}: '
          '${c.missing.map((k) => L10n.t(lang, k)).join(', ')}');
    }

    final head = '${L10n.t(lang, 'rvScore')}: ${score.round()}/100';
    if (tips.isEmpty) return '$head\n\n${L10n.t(lang, 'rvGood')}';
    return '$head\n\n${tips.map((t) => '- $t').join('\n')}';
  }

  // --------------------------------------------------------------- translate

  /// Creates a translated copy of [r]. Needs a server.
  Future<Resume> translateResume(Resume r, String target) async {
    if (!isRemote) throw AiException(L10n.t(r.lang, 'aiTranslateNeedsServer'));

    final res = await run(AiTask.translate, r, target: target);
    final start = res.text.indexOf('{');
    final end = res.text.lastIndexOf('}');
    if (start < 0 || end <= start) throw AiException('Invalid response');

    final Map<String, dynamic> map;
    try {
      map = jsonDecode(res.text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('Invalid response');
    }

    final json = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
    json['id'] = newId();
    final copy = Resume.fromJson(json);

    String? str(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
    List<Map<String, dynamic>> maps(dynamic v) => v is List
        ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    copy.jobTitle = str(map['jobTitle']) ?? copy.jobTitle;
    copy.summary = str(map['summary']) ?? copy.summary;

    final ex = maps(map['experiences']);
    for (var i = 0; i < copy.experiences.length && i < ex.length; i++) {
      copy.experiences[i].title = str(ex[i]['title']) ?? copy.experiences[i].title;
      copy.experiences[i].description =
          str(ex[i]['description']) ?? copy.experiences[i].description;
    }
    final ed = maps(map['education']);
    for (var i = 0; i < copy.education.length && i < ed.length; i++) {
      copy.education[i].degree = str(ed[i]['degree']) ?? copy.education[i].degree;
      copy.education[i].description =
          str(ed[i]['description']) ?? copy.education[i].description;
    }
    final sk = map['skills'];
    if (sk is List && sk.length == copy.skills.length) {
      copy.skills = sk.map((e) => '$e').toList();
    }
    final lg = maps(map['languages']);
    for (var i = 0; i < copy.languages.length && i < lg.length; i++) {
      copy.languages[i].name = str(lg[i]['name']) ?? copy.languages[i].name;
    }
    final pr = maps(map['projects']);
    for (var i = 0; i < copy.projects.length && i < pr.length; i++) {
      copy.projects[i].name = str(pr[i]['name']) ?? copy.projects[i].name;
      copy.projects[i].description =
          str(pr[i]['description']) ?? copy.projects[i].description;
    }

    copy.lang = target;
    final base = r.displayName.isEmpty ? L10n.t(target, 'untitled') : r.displayName;
    copy.fileName = '$base ($target)';
    copy.updatedAt = DateTime.now();
    return copy;
  }
}
