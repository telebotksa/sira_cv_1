import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/templates.dart';
import '../models/resume.dart';
import '../services/suggestions.dart';
import '../state/app_state.dart';
import 'paywall.dart';
import 'preview_page.dart';
import 'tr.dart';

/// Editing screen: one tab per resume section plus a design tab.
/// Changes are auto-saved (debounced) and flushed when leaving the screen.
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.resumeId});

  final String resumeId;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final AppState _app;
  late final Resume _r;
  Timer? _timer;
  final _skillCtl = TextEditingController();

  static const _tabs = [
    'personal',
    'summary',
    'experience',
    'education',
    'skills',
    'languages',
    'projects',
    'design',
  ];

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _r = _app.byId(widget.resumeId)!;
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Notifying listeners while the tree is being torn down is illegal, so
    // the final save is deferred to a microtask.
    final app = _app;
    final r = _r;
    scheduleMicrotask(() => app.save(r));
    _skillCtl.dispose();
    super.dispose();
  }

  void _flush() {
    _timer?.cancel();
    _app.save(_r);
  }

  /// Text edits: save later, no rebuild.
  void _save() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), _flush);
  }

  /// Structural edits: rebuild now and save later.
  void _touch() {
    if (mounted) setState(() {});
    _save();
  }

  void _openPreview() {
    _flush();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PreviewPage(resumeId: _r.id)),
    );
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 480,
      maxHeight: 480,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    _r.photoB64 = base64Encode(bytes);
    _touch();
  }

  @override
  Widget build(BuildContext context) {
    final title = _r.displayName.isEmpty ? context.tr('untitled') : _r.displayName;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton.icon(
              onPressed: _openPreview,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(context.tr('preview')),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final k in _tabs) Tab(text: context.tr(k))],
          ),
        ),
        body: TabBarView(
          children: [
            _personalTab(),
            _SummaryTab(r: _r, onChanged: _save),
            _experienceTab(),
            _educationTab(),
            _skillsTab(),
            _languagesTab(),
            _projectsTab(),
            _designTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- personal

  Widget _personalTab() {
    final photo = _r.photoB64;
    ImageProvider? img;
    if (photo != null && photo.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(photo));
      } catch (_) {
        img = null;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: img,
              child: img == null ? const Icon(Icons.person, size: 36) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.tr('choosePhoto')),
                  ),
                  if (img != null)
                    TextButton(
                      onPressed: () {
                        _r.photoB64 = null;
                        _touch();
                      },
                      child: Text(context.tr('removePhoto')),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _F(
          label: context.tr('resumeName'),
          value: _r.fileName,
          onChanged: (v) {
            _r.fileName = v;
            _save();
          },
        ),
        _F(
          label: context.tr('fullName'),
          value: _r.fullName,
          onChanged: (v) {
            _r.fullName = v;
            _save();
          },
        ),
        _F(
          label: context.tr('jobTitle'),
          value: _r.jobTitle,
          onChanged: (v) {
            _r.jobTitle = v;
            _save();
          },
        ),
        _F(
          label: context.tr('email'),
          value: _r.email,
          keyboard: TextInputType.emailAddress,
          onChanged: (v) {
            _r.email = v;
            _save();
          },
        ),
        _F(
          label: context.tr('phone'),
          value: _r.phone,
          keyboard: TextInputType.phone,
          onChanged: (v) {
            _r.phone = v;
            _save();
          },
        ),
        _F(
          label: context.tr('city'),
          value: _r.city,
          onChanged: (v) {
            _r.city = v;
            _save();
          },
        ),
        _F(
          label: context.tr('website'),
          value: _r.website,
          keyboard: TextInputType.url,
          onChanged: (v) {
            _r.website = v;
            _save();
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------- experience

  Widget _experienceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in _r.experiences)
          _card(
            key: ValueKey(e.id),
            title: e.title.isEmpty ? context.tr('experience') : e.title,
            onDelete: () {
              _r.experiences.remove(e);
              _touch();
            },
            children: [
              _F(
                key: ValueKey('${e.id}-title'),
                label: context.tr('position'),
                value: e.title,
                onChanged: (v) {
                  e.title = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${e.id}-company'),
                label: context.tr('company'),
                value: e.company,
                onChanged: (v) {
                  e.company = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${e.id}-loc'),
                label: context.tr('location'),
                value: e.location,
                onChanged: (v) {
                  e.location = v;
                  _save();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _F(
                      key: ValueKey('${e.id}-start'),
                      label: context.tr('startDate'),
                      value: e.start,
                      onChanged: (v) {
                        e.start = v;
                        _save();
                      },
                    ),
                  ),
                  if (!e.current) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _F(
                        key: ValueKey('${e.id}-end'),
                        label: context.tr('endDate'),
                        value: e.end,
                        onChanged: (v) {
                          e.end = v;
                          _save();
                        },
                      ),
                    ),
                  ],
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('present')),
                value: e.current,
                onChanged: (v) {
                  e.current = v;
                  _touch();
                },
              ),
              _F(
                key: ValueKey('${e.id}-desc'),
                label: context.tr('description'),
                value: e.description,
                lines: 4,
                onChanged: (v) {
                  e.description = v;
                  _save();
                },
              ),
            ],
          ),
        _addButton(() {
          _r.experiences.add(Experience());
          _touch();
        }),
      ],
    );
  }

  // --------------------------------------------------------------- education

  Widget _educationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in _r.education)
          _card(
            key: ValueKey(e.id),
            title: e.degree.isEmpty ? context.tr('education') : e.degree,
            onDelete: () {
              _r.education.remove(e);
              _touch();
            },
            children: [
              _F(
                key: ValueKey('${e.id}-degree'),
                label: context.tr('degree'),
                value: e.degree,
                onChanged: (v) {
                  e.degree = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${e.id}-school'),
                label: context.tr('school'),
                value: e.school,
                onChanged: (v) {
                  e.school = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${e.id}-loc'),
                label: context.tr('location'),
                value: e.location,
                onChanged: (v) {
                  e.location = v;
                  _save();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _F(
                      key: ValueKey('${e.id}-start'),
                      label: context.tr('startDate'),
                      value: e.start,
                      onChanged: (v) {
                        e.start = v;
                        _save();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _F(
                      key: ValueKey('${e.id}-end'),
                      label: context.tr('endDate'),
                      value: e.end,
                      onChanged: (v) {
                        e.end = v;
                        _save();
                      },
                    ),
                  ),
                ],
              ),
              _F(
                key: ValueKey('${e.id}-desc'),
                label: context.tr('description'),
                value: e.description,
                lines: 3,
                onChanged: (v) {
                  e.description = v;
                  _save();
                },
              ),
            ],
          ),
        _addButton(() {
          _r.education.add(Education());
          _touch();
        }),
      ],
    );
  }

  // ------------------------------------------------------------------ skills

  void _addSkill(String raw) {
    final s = raw.trim();
    if (s.isEmpty || _r.skills.contains(s)) return;
    _r.skills.add(s);
    _skillCtl.clear();
    _touch();
  }

  Widget _skillsTab() {
    final ideas = Suggestions.skillIdeas(_r);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _skillCtl,
                decoration: InputDecoration(labelText: context.tr('skillHint')),
                onSubmitted: _addSkill,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _addSkill(_skillCtl.text),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in _r.skills)
              InputChip(
                label: Text(s),
                onDeleted: () {
                  _r.skills.remove(s);
                  _touch();
                },
              ),
          ],
        ),
        if (ideas.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(context.tr('suggestions'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in ideas)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(s),
                  onPressed: () => _addSkill(s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------- languages

  Widget _languagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final l in _r.languages)
          _card(
            key: ValueKey(l.id),
            title: l.name.isEmpty ? context.tr('languages') : l.name,
            onDelete: () {
              _r.languages.remove(l);
              _touch();
            },
            children: [
              _F(
                key: ValueKey('${l.id}-name'),
                label: context.tr('langName'),
                value: l.name,
                onChanged: (v) {
                  l.name = v;
                  _save();
                },
              ),
              DropdownMenu<int>(
                key: ValueKey('${l.id}-level'),
                initialSelection: l.level,
                expandedInsets: EdgeInsets.zero,
                label: Text(context.tr('level')),
                dropdownMenuEntries: [
                  for (var i = 0; i < 5; i++)
                    DropdownMenuEntry(value: i, label: context.tr('lv$i')),
                ],
                onSelected: (v) {
                  if (v == null) return;
                  l.level = v;
                  _save();
                },
              ),
            ],
          ),
        _addButton(() {
          _r.languages.add(LangSkill());
          _touch();
        }),
      ],
    );
  }

  // ---------------------------------------------------------------- projects

  Widget _projectsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in _r.projects)
          _card(
            key: ValueKey(p.id),
            title: p.name.isEmpty ? context.tr('projects') : p.name,
            onDelete: () {
              _r.projects.remove(p);
              _touch();
            },
            children: [
              _F(
                key: ValueKey('${p.id}-name'),
                label: context.tr('projectName'),
                value: p.name,
                onChanged: (v) {
                  p.name = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${p.id}-link'),
                label: context.tr('projectLink'),
                value: p.link,
                keyboard: TextInputType.url,
                onChanged: (v) {
                  p.link = v;
                  _save();
                },
              ),
              _F(
                key: ValueKey('${p.id}-desc'),
                label: context.tr('description'),
                value: p.description,
                lines: 3,
                onChanged: (v) {
                  p.description = v;
                  _save();
                },
              ),
            ],
          ),
        _addButton(() {
          _r.projects.add(Project());
          _touch();
        }),
      ],
    );
  }

  // ------------------------------------------------------------------ design

  Future<void> _pickTemplate(TemplateDef t) async {
    if (t.premium && !_app.premium) {
      final ok = await showPaywall(context);
      if (!ok) return;
    }
    _r.templateId = t.id;
    _touch();
  }

  Widget _designTab() {
    final premium = context.watch<AppState>().premium;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(context.tr('template'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.66,
          children: [
            for (final t in templates)
              _TemplateCard(
                def: t,
                label: context.tr(t.nameKey),
                accent: Color(_r.accent),
                selected: _r.templateId == t.id,
                locked: t.premium && !premium,
                onTap: () => _pickTemplate(t),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(context.tr('accent'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in accentPalette)
              GestureDetector(
                onTap: () {
                  _r.accent = c;
                  _touch();
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(c),
                  child: _r.accent == c
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        DropdownMenu<String>(
          initialSelection: _r.lang,
          expandedInsets: EdgeInsets.zero,
          label: Text(context.tr('resumeLanguage')),
          dropdownMenuEntries: [
            for (final c in L10n.supported)
              DropdownMenuEntry(value: c, label: L10n.names[c]!),
          ],
          onSelected: (v) {
            if (v == null) return;
            _r.lang = v;
            _touch();
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- helpers

  Widget _card({
    required Key key,
    required String title,
    required VoidCallback onDelete,
    required List<Widget> children,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('delete'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _addButton(VoidCallback onPressed) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(context.tr('add')),
        ),
      );
}

/// Labeled text field that keeps its own controller (initial value only).
class _F extends StatelessWidget {
  const _F({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lines = 1,
    this.keyboard,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int lines;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        minLines: lines > 1 ? lines : 1,
        maxLines: lines > 1 ? 10 : 1,
        keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

/// Summary tab: text + auto draft + completeness meter + action verbs.
class _SummaryTab extends StatefulWidget {
  const _SummaryTab({required this.r, required this.onChanged});

  final Resume r;
  final VoidCallback onChanged;

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.r.summary);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final c = Suggestions.completeness(r);
    final verbs = Suggestions.actionVerbs(r.lang);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _ctl,
          minLines: 5,
          maxLines: 12,
          decoration: InputDecoration(labelText: context.tr('summary')),
          onChanged: (v) {
            r.summary = v;
            widget.onChanged();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_awesome),
            label: Text(context.tr('generate')),
            onPressed: () {
              final text = Suggestions.draftSummary(r);
              _ctl.text = text;
              r.summary = text;
              widget.onChanged();
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(context.tr('completeness'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: c.score, minHeight: 8),
        const SizedBox(height: 6),
        Text('${(c.score * 100).round()}%'),
        if (c.missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${context.tr('missing')}: ${c.missing.map(context.tr).join('، ')}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 24),
        Text(context.tr('actionVerbs'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [for (final v in verbs) Chip(label: Text(v))],
        ),
      ],
    );
  }
}

/// Small visual mock of a template used in the picker grid.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.def,
    required this.label,
    required this.accent,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final TemplateDef def;
  final String label;
  final Color accent;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  Widget _bar(double w, {Color? color, double h = 4}) => Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 4),
        color: color ?? Colors.grey.shade300,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final banner = def.header == HeaderKind.banner;
    final centered = def.header == HeaderKind.centered;

    final head = banner
        ? Container(height: 26, color: accent)
        : Column(
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              _bar(54, color: accent, h: 6),
              _bar(34),
            ],
          );

    final titleBar = def.title == TitleKind.band
        ? _bar(double.infinity, color: accent, h: 6)
        : _bar(28, color: def.title == TitleKind.accent ? accent : Colors.grey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      head,
                      const SizedBox(height: 6),
                      titleBar,
                      _bar(double.infinity),
                      _bar(double.infinity),
                      _bar(40),
                      const SizedBox(height: 4),
                      titleBar,
                      _bar(double.infinity),
                      _bar(50),
                    ],
                  ),
                  if (locked)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.lock, size: 16, color: Colors.orange),
                    ),
                ],
              ),
            ),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
