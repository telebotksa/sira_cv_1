import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/templates.dart';
import '../models/resume.dart';
import '../services/ai_service.dart';
import '../services/suggestions.dart';
import '../state/app_state.dart';
import 'ai_helpers.dart';
import 'ai_tab.dart';
import 'date_field.dart';
import 'paywall.dart';
import 'photo_editor_page.dart';
import 'preview_page.dart';
import 'tr.dart';

/// Editing screen: one tab per resume section, an AI tab and a design tab.
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

  /// Bumped when AI rewrites a text field, so the field is rebuilt with the
  /// new initial value.
  int _rev = 0;

  static const _tabs = [
    'personal',
    'summary',
    'experience',
    'education',
    'skills',
    'languages',
    'projects',
    'ai',
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
    // the final save is deferred to a microtask. Empty resumes are discarded.
    final app = _app;
    final r = _r;
    scheduleMicrotask(() {
      if (r.isBlank) {
        app.delete(r.id);
      } else {
        app.save(r);
      }
    });
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

  void _openResume(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorPage(resumeId: id)),
    );
  }

  // ------------------------------------------------------------------- photo

  Uint8List? _photoBytes() {
    final p = _r.photoB64;
    if (p == null || p.isEmpty) return null;
    try {
      return base64Decode(p);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _editPhoto(bytes);
  }

  Future<void> _editPhoto(Uint8List bytes) async {
    if (!mounted) return;
    final out = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => PhotoEditorPage(bytes: bytes)),
    );
    if (out == null) return;
    _r.photoB64 = base64Encode(out);
    _touch();
  }

  // ---------------------------------------------------------------------- AI

  Future<void> _aiBullets(Experience e) async {
    final title = context.trNow('aiBullets');
    final res = await runAi(
      context,
      AiTask.bullets,
      _r,
      input: '${e.title} ${e.company}'.trim(),
    );
    if (res == null || !mounted) return;
    await showAiSheet(
      context,
      title: title,
      result: res,
      onApply: () {
        final add = res.lines.join('\n');
        final old = e.description.trim();
        e.description = old.isEmpty ? add : '$old\n$add';
        _rev++;
        _touch();
      },
    );
  }

  Future<void> _aiImprove(Experience e) async {
    if (e.description.trim().isEmpty) return;
    final title = context.trNow('aiImprove');
    final res = await runAi(context, AiTask.improve, _r, input: e.description);
    if (res == null || !mounted) return;
    await showAiSheet(
      context,
      title: title,
      result: res,
      onApply: () {
        e.description = res.lines.join('\n');
        _rev++;
        _touch();
      },
    );
  }

  Future<void> _aiSkills() async {
    final title = context.trNow('aiSkills');
    final res = await runAi(
      context,
      AiTask.skills,
      _r,
      target: Suggestions.detectLang(_r),
    );
    if (res == null || !mounted) return;
    await showAiSheet(
      context,
      title: title,
      result: res,
      onApply: () => _addSkills(res.lines),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final title =
        _r.displayName.isEmpty ? context.tr('untitled') : _r.displayName;

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
            AiTab(r: _r, onChanged: _touch, onOpenResume: _openResume),
            _designTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- personal

  Widget _personalTab() {
    final photoBytes = _photoBytes();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage:
                  photoBytes == null ? null : MemoryImage(photoBytes),
              child:
                  photoBytes == null ? const Icon(Icons.person, size: 36) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.tr('choosePhoto')),
                  ),
                  if (photoBytes != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _editPhoto(photoBytes),
                      icon: const Icon(Icons.tune),
                      label: Text(context.tr('editPhoto')),
                    ),
                    TextButton(
                      onPressed: () {
                        _r.photoB64 = null;
                        _touch();
                      },
                      child: Text(context.tr('removePhoto')),
                    ),
                  ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DateField(
                      key: ValueKey('${e.id}-start'),
                      label: context.tr('startDate'),
                      value: e.start,
                      lang: _r.lang,
                      onChanged: (v) {
                        e.start = v;
                        _touch();
                      },
                    ),
                  ),
                  if (!e.current) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DateField(
                        key: ValueKey('${e.id}-end'),
                        label: context.tr('endDate'),
                        value: e.end,
                        lang: _r.lang,
                        onChanged: (v) {
                          e.end = v;
                          _touch();
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
                key: ValueKey('${e.id}-desc-$_rev'),
                label: context.tr('description'),
                value: e.description,
                lines: 4,
                onChanged: (v) {
                  e.description = v;
                  _save();
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _aiBullets(e),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(context.tr('aiBullets')),
                  ),
                  TextButton.icon(
                    onPressed: () => _aiImprove(e),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(context.tr('aiImprove')),
                  ),
                ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DateField(
                      key: ValueKey('${e.id}-start'),
                      label: context.tr('startDate'),
                      value: e.start,
                      lang: _r.lang,
                      onChanged: (v) {
                        e.start = v;
                        _touch();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      key: ValueKey('${e.id}-end'),
                      label: context.tr('endDate'),
                      value: e.end,
                      lang: _r.lang,
                      onChanged: (v) {
                        e.end = v;
                        _touch();
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

  void _addSkills(Iterable<String> items) {
    var changed = false;
    for (final raw in items) {
      final s = raw.trim();
      if (s.isEmpty || _r.skills.contains(s)) continue;
      _r.skills.add(s);
      changed = true;
    }
    if (changed) {
      _skillCtl.clear();
      _touch();
    }
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
                onSubmitted: (v) => _addSkills([v]),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _addSkills([_skillCtl.text]),
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
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: _aiSkills,
            icon: const Icon(Icons.auto_awesome),
            label: Text(context.tr('aiSkills')),
          ),
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
                  onPressed: () => _addSkills([s]),
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

/// Summary tab: text, AI writing/improving, completeness meter, action verbs.
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

  void _apply(String text) {
    _ctl.text = text;
    widget.r.summary = text;
    widget.onChanged();
    setState(() {});
  }

  Future<void> _generate() async {
    final title = context.trNow('aiGenerate');
    final res = await runAi(context, AiTask.summary, widget.r,
        input: widget.r.summary);
    if (res == null || !mounted) return;
    await showAiSheet(context,
        title: title, result: res, onApply: () => _apply(res.text));
  }

  Future<void> _improve() async {
    if (widget.r.summary.trim().isEmpty) return _generate();
    final title = context.trNow('aiImprove');
    final res = await runAi(context, AiTask.improve, widget.r,
        input: widget.r.summary);
    if (res == null || !mounted) return;
    await showAiSheet(context,
        title: title, result: res, onApply: () => _apply(res.text));
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.tr('aiGenerate')),
              onPressed: _generate,
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_fix_high),
              label: Text(context.tr('aiImprove')),
              onPressed: _improve,
            ),
          ],
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
              '${context.tr('missing')}: ${c.missing.map(context.tr).join(', ')}',
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
