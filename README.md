# Free AI CV Maker

Flutter resume builder for Android, iOS and Web. Original code and design.

## Features

- Starts with a language picker (18 languages: ar, en, hi, zh, es, es-MX, id, de, fr, it, nl, nb, pl, pt, pt-BR, ro, tr, vi). Arabic is RTL.
- Multi-resume management, auto-save locally.
- Sections: personal details + photo, summary, experience, education, skills, languages, projects.
- Photo editor: crop (pinch/drag), filters, brightness / contrast / saturation.
- Date fields open a calendar picker; dates are shown localized.
- Skills suggestions follow the script/language you typed the job title in, across 18 fields.
- AI tab: resume review, job-description match, tailored summary, cover letter, full-resume translation,
  plus AI buttons on the summary, experience bullets and skills.
- 6 templates, 8 accent colors, live PDF preview, Save / Share / Print.

## Run

```bash
flutter create . --project-name sira_cv --org com.yourcompany --platforms=android,ios,web
flutter pub get
flutter analyze
flutter test
flutter run
```

Delete `test/widget_test.dart` if `flutter create` generates it. On iOS add
`NSPhotoLibraryUsageDescription` to `Info.plist`.

PDF fonts (Cairo, Noto Sans, Devanagari, SC) are downloaded on first export, so the first export needs internet.

## AI

Without a server the app uses a basic offline mode (templates, keyword matching). For real AI, deploy
`backend/worker.js` (see `backend/README.md`) and build with:

```bash
flutter build apk --dart-define=AI_ENDPOINT=https://your-worker.workers.dev --dart-define=AI_TOKEN=your-token
```

In GitHub, set the repository variable `AI_ENDPOINT` (Settings > Secrets and variables > Actions > Variables).
The daily free quota (5) is enforced in the app only; enforce real limits in the worker.

## Ads and paid premium

See `docs/MONETIZATION.md`. Premium is currently a demo switch; ads SDK is not included.

## Structure

```
lib/
  main.dart               entry, theme, first-run language screen
  core/                   l10n + strings/, dates, templates
  models/resume.dart      data model + JSON
  services/               pdf_builder, suggestions, ai_service
  state/app_state.dart    resumes, locale, premium, AI quota
  ui/                     home, editor, ai_tab, photo editor, date field, preview, settings, paywall
backend/                  Cloudflare Worker AI proxy
```
