import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'state/app_state.dart';
import 'ui/home_page.dart';
import 'ui/language_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final state = AppState();
  await state.load();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const SiraApp(),
    ),
  );
}

class SiraApp extends StatelessWidget {
  const SiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.select<AppState, String>((s) => s.locale);
    final onboarded = context.select<AppState, bool>((s) => s.onboarded);
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      onGenerateTitle: (_) => L10n.t(locale, 'appName'),
      debugShowCheckedModeBanner: false,
      locale: L10n.localeOf(locale),
      supportedLocales: [for (final c in L10n.supported) L10n.localeOf(c)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      // The language picker is the first screen; after a choice we go to Home.
      home: onboarded ? const HomePage() : const LanguagePage(firstRun: true),
    );
  }
}
