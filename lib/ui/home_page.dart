import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/templates.dart';
import '../models/resume.dart';
import '../state/app_state.dart';
import 'editor_page.dart';
import 'settings_page.dart';
import 'tr.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, Resume r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorPage(resumeId: r.id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Resume r) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.tr('confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true) app.delete(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('myResumes')),
        actions: [
          IconButton(
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.tr('newResume')),
        onPressed: () => _open(context, app.createResume()),
      ),
      body: app.resumes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 72, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(context.tr('noResumes'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(context.tr('noResumesHint'),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: app.resumes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = app.resumes[i];
                final name = r.displayName;
                final subtitle = [
                  if (r.jobTitle.trim().isNotEmpty) r.jobTitle.trim(),
                  context.tr(templateById(r.templateId).nameKey),
                ].join(' · ');

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(r.accent),
                      foregroundColor: Colors.white,
                      child: Text(name.isEmpty ? '؟' : name.characters.first),
                    ),
                    title: Text(name.isEmpty ? context.tr('untitled') : name),
                    subtitle: Text(subtitle),
                    onTap: () => _open(context, r),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'dup') app.duplicate(r);
                        if (v == 'del') _confirmDelete(context, r);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'dup',
                          child: Text(ctx.trNow('duplicate')),
                        ),
                        PopupMenuItem(
                          value: 'del',
                          child: Text(ctx.trNow('delete')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
