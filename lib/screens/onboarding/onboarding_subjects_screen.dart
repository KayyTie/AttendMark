import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/app_state.dart';
import '../../models/subject.dart';
import 'timetable_setup_screen.dart';

class OnboardingSubjectsScreen extends StatefulWidget {
  const OnboardingSubjectsScreen({super.key});

  @override
  State<OnboardingSubjectsScreen> createState() =>
      _OnboardingSubjectsScreenState();
}

class _OnboardingSubjectsScreenState extends State<OnboardingSubjectsScreen> {
  static const _defaultColors = [
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

  Future<void> _addOrEditSubject({Subject? existing}) async {
    final appState = context.read<AppState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.subjectCode ?? '');
    final profCtrl = TextEditingController(text: existing?.professor ?? '');
    String selectedColor = existing?.colorHex ??
        _defaultColors[Random().nextInt(_defaultColors.length)];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Subject' : 'Edit Subject'),
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
                  decoration:
                      const InputDecoration(labelText: 'Code (e.g. CS101)'),
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
                    ..._defaultColors.map((c) {
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
                    GestureDetector(
                      onTap: () {
                        Color picked = Color(
                            int.parse(selectedColor.replaceFirst('#', '0xFF')));
                        showDialog(
                          context: ctx,
                          builder: (c2) => AlertDialog(
                            title: const Text('Pick a color'),
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
                if (name.isEmpty) return;
                final code = codeCtrl.text.trim();
                final prof = profCtrl.text.trim();

                final subject = Subject(
                  id: existing?.id,
                  sessionId: appState.currentSession!.id!,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Subjects'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add the subjects you\'ll be attending this session.\nYou can always add more later.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: appState.subjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book,
                              size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No subjects yet.\nTap + below to add.',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: appState.subjects.length,
                      itemBuilder: (ctx, i) {
                        final subject = appState.subjects[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: subject.colorHex != null
                                ? Color(int.parse(subject.colorHex!
                                    .replaceFirst('#', '0xFF')))
                                : Colors.grey,
                          ),
                          title: Text(subject.name),
                          subtitle: Text([
                            if (subject.subjectCode?.isNotEmpty == true)
                              subject.subjectCode!,
                            if (subject.professor?.isNotEmpty == true)
                              subject.professor!,
                          ].join(' • ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blue),
                                onPressed: () =>
                                    _addOrEditSubject(existing: subject),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  await appState.deleteSubject(subject.id!);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addOrEditSubject,
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: appState.subjects.isEmpty
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TimetableSetupScreen(),
                        ),
                      );
                    },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Continue to Schedule Setup',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
