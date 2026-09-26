import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sira_cv/core/dates.dart';
import 'package:sira_cv/core/l10n.dart';
import 'package:sira_cv/core/strings/en.dart';
import 'package:sira_cv/models/resume.dart';
import 'package:sira_cv/services/ai_service.dart';
import 'package:sira_cv/services/suggestions.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  Resume sample({String lang = 'en'}) => Resume(
        lang: lang,
        fullName: 'Ali Test',
        jobTitle: 'Software Engineer',
        email: 'a@b.com',
        phone: '123',
        skills: ['Dart', 'Flutter', 'SQL'],
        experiences: [
          Experience(title: 'Dev', start: '2018-01', current: true),
        ],
        education: [Education(degree: 'BSc')],
        languages: [LangSkill(name: 'Arabic', level: 4)],
        projects: [Project(name: 'App')],
      );

  group('model', () {
    test('JSON round trip keeps data', () {
      final r = sample();
      final copy = Resume.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(copy.fullName, 'Ali Test');
      expect(copy.skills, ['Dart', 'Flutter', 'SQL']);
      expect(copy.experiences.single.current, true);
      expect(copy.languages.single.level, 4);
      expect(copy.projects.single.name, 'App');
    });

    test('missing ids get a fresh id', () {
      final e = Experience.fromJson({'title': 'x'});
      expect(e.id, isNotEmpty);
    });

    test('isBlank', () {
      expect(Resume().isBlank, true);
      expect(Resume(fullName: 'x').isBlank, false);
      expect(Resume(skills: ['a']).isBlank, false);
    });
  });

  group('localization', () {
    test('every language has every key with the same placeholders', () {
      final ph = RegExp(r'\{\w+\}');
      for (final code in L10n.supported) {
        for (final entry in stringsEn.entries) {
          final v = L10n.t(code, entry.key);
          expect(v, isNotEmpty, reason: '$code/${entry.key}');
          final a = ph.allMatches(entry.value).map((m) => m.group(0)).toList()..sort();
          final b = ph.allMatches(v).map((m) => m.group(0)).toList()..sort();
          expect(b, a, reason: '$code/${entry.key} placeholders');
        }
      }
    });

    test('device locale matching', () {
      expect(L10n.matchDevice('es', 'MX'), 'es_MX');
      expect(L10n.matchDevice('es', 'AR'), 'es');
      expect(L10n.matchDevice('pt', 'BR'), 'pt_BR');
      expect(L10n.matchDevice('no', null), 'nb');
      expect(L10n.matchDevice('zh', 'TW'), 'zh');
      expect(L10n.matchDevice('xx', null), 'en');
    });

    test('locale objects', () {
      expect(L10n.localeOf('pt_BR').countryCode, 'BR');
      expect(L10n.localeOf('ar').countryCode, isNull);
    });

    test('only Arabic is RTL', () {
      expect(L10n.supported.where(L10n.isRtl).toList(), ['ar']);
    });
  });

  group('dates', () {
    test('parse and format', () {
      expect(Dates.parse('2021-03'), DateTime(2021, 3, 1));
      expect(Dates.parse('2021-03-15'), DateTime(2021, 3, 1));
      expect(Dates.parse('Jan 2021'), isNull);
      expect(Dates.parse('2021-13'), isNull);
      expect(Dates.toIso(DateTime(2021, 3, 9)), '2021-03');
      expect(Dates.format('2021-03', 'en'), 'Mar 2021');
      expect(Dates.format('Jan 2021', 'en'), 'Jan 2021');
    });

    test('Arabic dates use Western digits', () {
      final s = Dates.format('2021-03', 'ar');
      expect(RegExp(r'[٠-٩]').hasMatch(s), false);
      expect(s, contains('2021'));
    });

    test('digit conversion', () {
      expect(Dates.westernDigits('٢٠٢١ ۲۰۲۱ २०२१'), '2021 2021 2021');
    });
  });

  group('suggestions', () {
    test('years of experience uses earliest start year', () {
      expect(Suggestions.yearsOfExperience(sample(), now: DateTime(2026, 6, 1)), 8);
    });

    test('draft summary mentions job title and skills', () {
      final s = Suggestions.draftSummary(sample(), now: DateTime(2026, 6, 1));
      expect(s, contains('Software Engineer'));
      expect(s, contains('Dart, Flutter, SQL'));
      expect(s, contains('8+'));
    });

    test('completeness reports missing summary', () {
      final c = Suggestions.completeness(sample());
      expect(c.missing, ['summary']);
      expect(c.score, closeTo(7 / 8, 0.001));
    });

    test('language detection follows the script the user typed', () {
      expect(Suggestions.detectLang(Resume(lang: 'en', jobTitle: 'محاسب')), 'ar');
      expect(Suggestions.detectLang(Resume(lang: 'ar', jobTitle: 'Accountant')), 'en');
      expect(Suggestions.detectLang(Resume(lang: 'de', jobTitle: 'Buchhalter')), 'de');
      expect(Suggestions.detectLang(Resume(lang: 'fr')), 'fr');
      expect(Suggestions.detectLang(Resume(lang: 'en', jobTitle: '会计')), 'zh');
    });

    test('Arabic job title gets Arabic skills plus tools', () {
      final r = Resume(lang: 'en', jobTitle: 'محاسب');
      final ideas = Suggestions.skillIdeas(r);
      expect(ideas, contains('التقارير المالية'));
      expect(ideas, contains('Excel'));
      expect(ideas.length, greaterThan(15));
    });

    test('other languages get tools and translated soft skills', () {
      final r = Resume(lang: 'de', jobTitle: 'Software Engineer');
      final ideas = Suggestions.skillIdeas(r);
      expect(ideas, contains('Git'));
      expect(ideas, contains('Kommunikation'));
      expect(ideas, isNot(contains('Clean code')));
    });

    test('skills already added are not suggested again', () {
      final r = Resume(lang: 'en', jobTitle: 'Developer', skills: ['Git']);
      expect(Suggestions.skillIdeas(r), isNot(contains('Git')));
    });

    test('short keys match whole words only', () {
      // "quality" contains "ui" but is not a design job.
      final r = Resume(lang: 'en', jobTitle: 'Quality Inspector');
      expect(Suggestions.skillIdeas(r), isNot(contains('Figma')));
    });
  });

  group('AI service (offline mode)', () {
    final ai = AiService(endpoint: '');

    test('is not remote without an endpoint', () {
      expect(ai.isRemote, false);
    });

    test('review scores and gives tips', () async {
      final res = await ai.run(AiTask.review, sample());
      expect(res.local, true);
      expect(res.text, contains('Resume score'));
    });

    test('job match finds matched and missing keywords', () async {
      final r = Resume(lang: 'en', skills: ['Flutter', 'Dart']);
      final res = await ai.run(
        AiTask.jobMatch,
        r,
        job: 'We need Flutter and Dart and Kubernetes',
      );
      expect(res.text, contains('50%'));
      expect(res.text, contains('kubernetes'));
    });

    test('improve polishes lines', () async {
      final res = await ai.run(AiTask.improve, sample(), input: '  led  a team\nbuilt apps ');
      expect(res.lines, ['Led a team.', 'Built apps.']);
    });

    test('bullet lines keep skills that start with digits', () {
      expect(const AiResult('- 3D Modeling\n2) Excel').lines, ['3D Modeling', 'Excel']);
    });

    test('cover letter fills the template', () async {
      final res = await ai.run(AiTask.coverLetter, sample());
      expect(res.text, contains('Software Engineer'));
      expect(res.text, contains('Ali Test'));
    });

    test('translation needs a server', () async {
      expect(
        () => ai.run(AiTask.translate, sample(), target: 'de'),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('AI service (server mode)', () {
    test('sends the task and returns the text', () async {
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['task'], 'summary');
        expect(body['lang'], 'en');
        expect(req.headers['x-app-token'], 'tok');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'text': 'Hello مرحبا'})),
          200,
        );
      });
      final ai = AiService(endpoint: 'https://example.test/ai', token: 'tok', client: client);
      final res = await ai.run(AiTask.summary, sample());
      expect(res.text, 'Hello مرحبا');
      expect(res.local, false);
    });

    test('non-200 becomes an AiException', () async {
      final client = MockClient((_) async => http.Response('nope', 502));
      final ai = AiService(endpoint: 'https://example.test/ai', client: client);
      expect(() => ai.run(AiTask.summary, sample()), throwsA(isA<AiException>()));
    });

    test('translateResume builds a translated copy', () async {
      final translated = {
        'jobTitle': 'Softwareentwickler',
        'summary': 'Zusammenfassung',
        'experiences': [
          {'title': 'Entwickler', 'description': 'Baute Apps'},
        ],
        'education': [
          {'degree': 'Bachelor', 'description': ''},
        ],
        'skills': ['Git', 'SQL', 'Dart'],
        'languages': [
          {'name': 'Arabisch'},
        ],
        'projects': [
          {'name': 'App', 'description': ''},
        ],
      };
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['task'], 'translate');
        expect(body['target'], 'de');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'text': 'Here you go:\n${jsonEncode(translated)}'})),
          200,
        );
      });
      final ai = AiService(endpoint: 'https://example.test/ai', client: client);
      final original = sample();
      final copy = await ai.translateResume(original, 'de');

      expect(copy.id, isNot(original.id));
      expect(copy.lang, 'de');
      expect(copy.jobTitle, 'Softwareentwickler');
      expect(copy.experiences.single.title, 'Entwickler');
      expect(copy.experiences.single.start, '2018-01'); // untouched fields survive
      expect(copy.skills, ['Git', 'SQL', 'Dart']);
      expect(copy.languages.single.name, 'Arabisch');
      expect(copy.languages.single.level, 4);
      // The original is not modified.
      expect(original.jobTitle, 'Software Engineer');
      expect(original.skills, ['Dart', 'Flutter', 'SQL']);
    });
  });
}
