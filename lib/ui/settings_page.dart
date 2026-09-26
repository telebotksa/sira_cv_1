import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../state/app_state.dart';
import 'tr.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(
              context.tr('uiLanguage'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final code in L10n.supported)
            ListTile(
              title: Text(L10n.names[code]!),
              trailing: app.locale == code
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => app.setLocale(code),
            ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.workspace_premium),
            title: Text(context.tr('premium')),
            subtitle: app.premium ? Text(context.tr('premiumActive')) : null,
            value: app.premium,
            onChanged: app.setPremium,
          ),
          const Divider(),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: context.tr('appName'),
            applicationVersion: '1.0.0',
            child: Text(context.tr('about')),
          ),
        ],
      ),
    );
  }
}
