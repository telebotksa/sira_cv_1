# Sira (سيرة) — multilingual resume builder

Flutter app for Android, iOS and Web. Original code and design.

## First run

The project contains `lib/`, `test/` and `pubspec.yaml`. Generate the platform folders once:

```bash
flutter create . --project-name sira_cv --org com.yourcompany --platforms=android,ios,web
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter create .` will not overwrite `lib/` or `pubspec.yaml`. If it replaces `test/widget_test.dart`
with its default file, delete that file (it references a counter app).

### Platform notes

- **iOS** (`ios/Runner/Info.plist`): add `NSPhotoLibraryUsageDescription` (used by the photo picker).
- **Android**: nothing extra for gallery picking. Set your `applicationId` and app icon.
- **Fonts / offline**: the PDF uses the Cairo font (Arabic + Latin) fetched on first export via the
  `printing` package. To work fully offline, bundle a font in `assets/` and load it with
  `pw.Font.ttf(await rootBundle.load(...))` in `lib/services/pdf_builder.dart`.

## What is included

- Multi-resume management (create, duplicate, delete), auto-save to local storage
- Sections: personal details + photo, summary, experience, education, skills, languages, projects
- 6 templates (3 free, 3 premium-gated), 8 accent colors, live PDF preview, print / share / save
- 5 languages (ar, en, fr, es, tr) for both the app UI and the resume itself, with RTL support
- Offline "smart" helpers: summary draft, strong action verbs, skill ideas, completeness score

## Not included yet (needs your accounts)

- **Cloud accounts and sync**: data is local only. Add Firebase Auth + Firestore and mirror
  `AppState` reads/writes (`lib/state/app_state.dart` is the single persistence point).
- **Real purchases**: `showPaywall` is a demo unlock. Wire `in_app_purchase` or RevenueCat.
- **LLM-based suggestions**: `lib/services/suggestions.dart` is rule-based; swap
  `draftSummary` for a call to your own backend (never ship an API key inside the app).

## Structure

```
lib/
  main.dart               app entry, theme, localization delegates
  core/                   l10n strings, template definitions
  models/resume.dart      data model + JSON
  services/               pdf_builder.dart, suggestions.dart
  state/app_state.dart    resumes, locale, premium, persistence
  ui/                     home, editor (tabs), preview, settings, paywall
```
