import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../state/app_state.dart';
import 'language_page.dart';
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
            leading: const Icon(Icons.language),
            title: Text(context.tr('uiLanguage')),
            subtitle: Text(L10n.names[app.locale] ?? app.locale),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguagePage()),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextFormField(
              initialValue: app.aiEndpointOverride,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.tr('aiServer'),
                helperText: context.tr('aiServerHint'),
                prefixIcon: const Icon(Icons.auto_awesome),
              ),
              onChanged: app.setAiEndpoint,
            ),
          ),
          if (app.ai.isRemote)
            ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(context.tr('aiFreeLeft')),
              trailing: Text(app.premium ? '∞' : '${app.aiLeft}'),
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
