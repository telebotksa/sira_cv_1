import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sira_cv/core/l10n.dart';
import 'package:sira_cv/models/resume.dart';
import 'package:sira_cv/services/suggestions.dart';

void main() {
  Resume sample() => Resume(
        fullName: 'Ali Test',
        jobTitle: 'Software Engineer',
        email: 'a@b.com',
        phone: '123',
        skills: ['Dart', 'Flutter', 'SQL'],
        experiences: [Experience(title: 'Dev', start: 'Jan 2018', current: true)],
        education: [Education(degree: 'BSc')],
        languages: [LangSkill(name: 'Arabic', level: 4)],
        projects: [Project(name: 'App')],
      );

  test('Resume JSON round trip keeps data', () {
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

  test('years of experience uses earliest start year', () {
    final r = sample();
    expect(Suggestions.yearsOfExperience(r, now: DateTime(2026, 6, 1)), 8);
  });

  test('draft summary mentions job title and skills', () {
    final r = sample()..lang = 'en';
    final s = Suggestions.draftSummary(r, now: DateTime(2026, 6, 1));
    expect(s, contains('Software Engineer'));
    expect(s, contains('Dart, Flutter, SQL'));
    expect(s, contains('8+'));
  });

  test('completeness reports missing summary', () {
    final c = Suggestions.completeness(sample());
    expect(c.missing, ['summary']);
    expect(c.score, closeTo(7 / 8, 0.001));
  });

  test('every language defines every English key', () {
    final en = L10n.t('en', 'appName');
    expect(en, isNotEmpty);
    for (final code in L10n.supported) {
      for (final key in ['myResumes', 'experience', 'lv4', 'tpl_executive']) {
        expect(L10n.t(code, key), isNot(key), reason: '$code missing $key');
      }
    }
  });
}
