import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../state/app_state.dart';
import 'tr.dart';

/// Language picker. Shown full-screen on first launch (`firstRun: true`),
/// and reused from Settings.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    void pick(String code) {
      app.setLocale(code);
      if (firstRun) {
        app.completeOnboarding();
      } else {
        Navigator.of(context).pop();
      }
    }

    return Scaffold(
      appBar: firstRun ? null : AppBar(title: Text(context.tr('uiLanguage'))),
      body: SafeArea(
        child: Column(
          children: [
            if (firstRun)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/icon/icon.png',
                          width: 84, height: 84),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('appName'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('chooseLanguage'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: L10n.supported.length,
                itemBuilder: (context, i) {
                  final code = L10n.supported[i];
                  final selected = app.locale == code;
                  return Material(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => pick(code),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                L10n.names[code]!,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
