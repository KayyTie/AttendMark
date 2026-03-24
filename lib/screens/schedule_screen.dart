import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/app_state.dart';
import '../models/modifier.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ScheduleScreen extends StatefulWidget {
  final VoidCallback onOpenDrawer;
  const ScheduleScreen({super.key, required this.onOpenDrawer});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: widget.onOpenDrawer,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Subjects'),
            Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
            Tab(icon: Icon(Icons.label_outline), text: 'Modifiers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_SubjectsTab(), _TimetableTab(), _ModifiersTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SUBJECTS TAB
// ─────────────────────────────────────────────────

class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab();

  static const _colors = [
    '#FFCDD2',
    '#F8BBD0',
    '#E1BEE7',
    '#D1C4E9',
    '#C5CAE9',
    '#BBDEFB',
    '#B3E5FC',
    '#B2EBF2',
    '#B2DFDB',
    '#C8E6C9',
    '#DCEDC8',
    '#FFF9C4',
  ];

  Future<void> _showSubjectDialog(BuildContext context, AppState appState,
      {Subject? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.subjectCode ?? '');
    final profCtrl = TextEditingController(text: existing?.professor ?? '');
    String selectedColor =
        existing?.colorHex ?? _colors[Random().nextInt(_colors.length)];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'New Subject' : 'Edit Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                  autofocus: true,
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Subject Code (e.g. CS101)'),
                ),
                TextField(
                  controller: profCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Professor Name'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Colour:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._colors.map((c) {
                      final color =
                          Color(int.parse(c.replaceFirst('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => setSt(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == c
                                ? Border.all(width: 3, color: Colors.black87)
                                : null,
                          ),
                        ),
                      );
                    }),
                    // Custom Color Picker Button
                    GestureDetector(
                      onTap: () async {
                        Color picked = Color(
                            int.parse(selectedColor.replaceFirst('#', '0xFF')));
                        showDialog(
                          context: ctx,
                          builder: (c2) => AlertDialog(
                            title: const Text('Pick a color!'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: picked,
                                onColorChanged: (ch) => picked = ch,
                                enableAlpha: false,
                                displayThumbColor: true,
                                pickerAreaHeightPercent: 0.8,
                              ),
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Select'),
                                onPressed: () {
                                  setSt(() {
                                    selectedColor =
                                        '#${picked.value.toRadixString(16).substring(2).toUpperCase()}';
                                  });
                                  Navigator.of(c2).pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Icon(Icons.add, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                final prof = profCtrl.text.trim();
                if (name.isEmpty) return;

                final subject = Subject(
                  id: existing?.id,
                  sessionId:
                      existing?.sessionId ?? appState.currentSession!.id!,
                  name: name,
                  colorHex: selectedColor,
                  subjectCode: code.isEmpty ? null : code,
                  professor: prof.isEmpty ? null : prof,
                );

                if (existing == null) {
                  await appState.addSubject(subject);
                } else {
                  await appState.updateSubject(subject);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.currentSession == null) {
      return const Center(child: Text('No active session.'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectDialog(context, appState),
        child: const Icon(Icons.add),
      ),
      body: appState.subjects.isEmpty
          ? const Center(child: Text('No subjects yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: appState.subjects.length,
              itemBuilder: (ctx, i) {
                final subject = appState.subjects[i];
                final subtitleParts = [
                  if (subject.subjectCode?.isNotEmpty == true)
                    subject.subjectCode!,
                  if (subject.professor?.isNotEmpty == true) subject.professor!,
                ];
                final subjectColor = subject.colorHex != null
                    ? Color(
                        int.parse(subject.colorHex!.replaceFirst('#', '0xFF')))
                    : Colors.grey;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: subjectColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(subject.name),
                    subtitle: subtitleParts.isNotEmpty
                        ? Text(subtitleParts.join(' • '))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blue),
                          onPressed: () => _showSubjectDialog(context, appState,
                              existing: subject),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Subject?'),
                                content: Text(
                                    'Delete "${subject.name}"? This will remove all related timetable entries.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await appState.deleteSubject(subject.id!);
                            }
                          },
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

// ─────────────────────────────────────────────────
// TIMETABLE TAB
// ─────────────────────────────────────────────────

class _TimetableTab extends StatefulWidget {
  const _TimetableTab();

  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab> {
  int _selectedDay = DateTime.now().weekday;

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _openEntryDialog(BuildContext context, AppState appState,
      {TimetableEntry? existing}) async {
    TimeOfDay startTime = existing?.startTime ?? TimeOfDay.now();
    TimeOfDay endTime = existing?.endTime ??
        TimeOfDay(
            hour: (TimeOfDay.now().hour + 1) % 24,
            minute: TimeOfDay.now().minute);
    bool isBreak = existing?.isBreak ?? false;
    int? modifierId = existing?.modifierId;
    int? subjectId = existing?.subjectId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null
              ? 'Add Slot – ${_dayNames[_selectedDay - 1]}'
              : 'Edit Slot – ${_dayNames[_selectedDay - 1]}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: startTime);
                          if (t != null) setSt(() => startTime = t);
                        },
                        child: Text('Start: ${startTime.format(ctx)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: endTime);
                          if (t != null) setSt(() => endTime = t);
                        },
                        child: Text('End: ${endTime.format(ctx)}'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Is Break?'),
                  value: isBreak,
                  onChanged: (v) => setSt(() {
                    isBreak = v;
                    if (v) {
                      subjectId = null;
                      modifierId = null; // Also clear modifier if it's a break
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!isBreak) ...[
                  // Modifier picker
                  DropdownButtonFormField<int?>(
                    decoration:
                        const InputDecoration(labelText: 'Modifier'),
                    value: modifierId,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ...appState.modifiers.map((m) => DropdownMenuItem(
                          value: m.id, child: Text(m.name))),
                    ],
                    onChanged: (v) => setSt(() => modifierId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    decoration: const InputDecoration(labelText: 'Subject'),
                    value: subjectId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...appState.subjects.map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setSt(() => subjectId = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
              final entry = TimetableEntry(
                id: existing?.id,
                sessionId: appState.currentSession!.id!,
                dayOfWeek: _selectedDay,
                startTime: startTime,
                endTime: endTime,
                isBreak: isBreak,
                subjectId: isBreak ? null : subjectId,
                modifierId: isBreak ? null : modifierId,
              );

                if (existing != null) {
                  await appState.updateTimetableEntry(entry);
                } else {
                  await appState.addTimetableEntry(entry);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<TimetableEntry> _sortedEntries(AppState appState) {
    return appState.timetableEntries
        .where((e) => e.dayOfWeek == _selectedDay)
        .toList()
      ..sort((a, b) {
        final aMin = a.startTime.hour * 60 + a.startTime.minute;
        final bMin = b.startTime.hour * 60 + b.startTime.minute;
        return aMin.compareTo(bMin);
      });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.currentSession == null) {
      return const Center(child: Text('No active session.'));
    }

    final dayEntries = _sortedEntries(appState);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntryDialog(context, appState),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              final day = i + 1;
              final isSelected = _selectedDay == day;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _dayNames[i].substring(0, 3),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: dayEntries.isEmpty
                ? const Center(child: Text('No slots. Tap + to add.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: dayEntries.length,
                    itemBuilder: (ctx, i) {
                      final entry = dayEntries[i];
                      final subject = entry.subjectId != null
                          ? appState.subjects
                              .where((s) => s.id == entry.subjectId)
                              .firstOrNull
                          : null;

                      final modifier = entry.modifierId != null
                          ? appState.modifiers
                              .where((m) => m.id == entry.modifierId)
                              .firstOrNull
                          : null;

                      String modTag = modifier != null ? ' (${modifier.name})' : '';

                      if (entry.isBreak) {
                        return ListTile(
                          leading: const Icon(Icons.free_breakfast),
                          title: const Text('Break'),
                          subtitle: Text(
                              '${entry.startTime.format(context)} – ${entry.endTime.format(context)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blue),
                                onPressed: () => _openEntryDialog(
                                    context, appState,
                                    existing: entry),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: ctx,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete Slot?'),
                                      content: const Text(
                                          'Are you sure you want to delete this slot?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await appState
                                        .deleteTimetableEntry(entry.id!);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      final subjectColor = subject?.colorHex != null
                          ? Color(int.parse(
                              subject!.colorHex!.replaceFirst('#', '0xFF')))
                          : Colors.grey.shade400;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: subjectColor, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text('${subject?.name ?? "None"}$modTag'),
                          subtitle: Text(
                              '${entry.startTime.format(context)} – ${entry.endTime.format(context)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blue),
                                onPressed: () => _openEntryDialog(
                                    context, appState,
                                    existing: entry),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: ctx,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete Slot?'),
                                      content: const Text(
                                          'Are you sure you want to delete this slot? All attendance records for this slot will be permanently deleted.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await appState
                                        .deleteTimetableEntry(entry.id!);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MODIFIERS TAB
// ─────────────────────────────────────────────────

class _ModifiersTab extends StatelessWidget {
  const _ModifiersTab();

  Future<void> _showModifierDialog(BuildContext context, AppState appState,
      {Modifier? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String? selectedColor = existing?.colorHex;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'New Modifier' : 'Edit Modifier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Modifier Name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Color (optional):'),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      Color picked = selectedColor != null
                          ? Color(int.parse(
                              selectedColor!.replaceFirst('#', '0xFF')))
                          : Colors.blue;
                      await showDialog(
                        context: ctx,
                        builder: (c2) => AlertDialog(
                          title: const Text('Pick a color'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: picked,
                              onColorChanged: (c) => picked = c,
                              enableAlpha: false,
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('Clear'),
                              onPressed: () {
                                setSt(() => selectedColor = null);
                                Navigator.of(c2).pop();
                              },
                            ),
                            TextButton(
                              child: const Text('Select'),
                              onPressed: () {
                                setSt(() {
                                  selectedColor =
                                      '#${picked.value.toRadixString(16).substring(2).toUpperCase()}';
                                });
                                Navigator.of(c2).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selectedColor != null
                            ? Color(int.parse(
                                selectedColor!.replaceFirst('#', '0xFF')))
                            : null,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: selectedColor == null
                          ? const Icon(Icons.palette_outlined, size: 18)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final modifier = Modifier(
                    id: existing?.id, name: name, colorHex: selectedColor);
                if (existing == null) {
                  await appState.addModifier(modifier);
                } else {
                  await appState.updateModifier(modifier);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showModifierDialog(context, appState),
        child: const Icon(Icons.add),
      ),
      body: appState.modifiers.isEmpty
          ? const Center(
              child: Text('No modifiers yet. Tap + to add one.',
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: appState.modifiers.length,
              itemBuilder: (ctx, i) {
                final modifier = appState.modifiers[i];
                final color = modifier.colorHex != null
                    ? Color(int.parse(
                        modifier.colorHex!.replaceFirst('#', '0xFF')))
                    : Theme.of(context).colorScheme.onSurfaceVariant;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(modifier.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.blue),
                        onPressed: () => _showModifierDialog(context, appState,
                            existing: modifier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Modifier?'),
                              content: Text(
                                  'Delete "${modifier.name}"? Assigned timetable slots will lose this modifier.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(c, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () =>
                                        Navigator.pop(c, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await appState.deleteModifier(modifier.id!);
                          }
                        },
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
