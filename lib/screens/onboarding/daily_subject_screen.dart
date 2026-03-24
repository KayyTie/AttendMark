import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/subject.dart';
import '../../models/timetable_entry.dart';
import '../../repositories/timetable_repository.dart';
import '../main_home.dart';
import 'dart:math';

// We import the private class from the previous screen for the data structure
// A cleaner way is a shared model, but for quick onboarding this structure works.
class DailySubjectScreen extends StatefulWidget {
  final List<int> selectedDays;
  final List<dynamic> dailySlots; // passed from previous screen

  const DailySubjectScreen({
    super.key,
    required this.selectedDays,
    required this.dailySlots,
  });

  @override
  State<DailySubjectScreen> createState() => _DailySubjectScreenState();
}

class _DailySubjectScreenState extends State<DailySubjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // dayOfWeek -> (slotIndex -> subjectId?)
  final Map<int, Map<int, int?>> _assignedSubjects = {};

  // List of created subjects — we read from AppState instead of a local list

  final TimetableRepository _timetableRepo = TimetableRepository();

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.selectedDays.length, vsync: this);

    for (var day in widget.selectedDays) {
      _assignedSubjects[day] = {};
      for (int i = 0; i < widget.dailySlots.length; i++) {
        _assignedSubjects[day]![i] = null;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createNewSubject() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final profController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subject'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
                autofocus: true,
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                    labelText: 'Subject Code (e.g. CS101)'),
              ),
              TextField(
                controller: profController,
                decoration: const InputDecoration(labelText: 'Professor Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      final appState = context.read<AppState>();

      final colors = [
        '#FFCDD2',
        '#F8BBD0',
        '#E1BEE7',
        '#D1C4E9',
        '#C5CAE9',
        '#BBDEFB',
        '#B3E5FC',
        '#B2EBF2',
        '#B2DFDB',
        '#C8E6C9'
      ];
      final randomColor = colors[Random().nextInt(colors.length)];
      final code = codeController.text.trim();
      final prof = profController.text.trim();

      final newSubject = Subject(
        sessionId: appState.currentSession!.id!,
        name: nameController.text.trim(),
        colorHex: randomColor,
        subjectCode: code.isEmpty ? null : code,
        professor: prof.isEmpty ? null : prof,
      );

      await appState.addSubject(newSubject);
      setState(() {});
    }
  }

  String _getDayName(int day) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return names[day - 1];
  }

  Future<void> _finishSetup() async {
    final appState = context.read<AppState>();
    final sessionId = appState.currentSession!.id!;

    // Build the timetable entries
    for (var day in widget.selectedDays) {
      for (int i = 0; i < widget.dailySlots.length; i++) {
        final slot = widget.dailySlots[i];
        final subjectId = _assignedSubjects[day]![i];

        // Ensure we handle breaks properly. If the slot is marked as a break, ignore subject.
        final entry = TimetableEntry(
          sessionId: sessionId,
          dayOfWeek: day,
          startTime: slot.startTime,
          endTime: slot.endTime,
          isBreak: slot.isBreak,
          subjectId: slot.isBreak ? null : subjectId,
        );

        await _timetableRepo.create(entry);
      }
    }

    // Refresh app state
    await appState.loadSessionData(sessionId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainHome()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Subjects'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: widget.selectedDays
              .map((day) => Tab(text: _getDayName(day)))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subjects available:'),
                TextButton.icon(
                  onPressed: _createNewSubject,
                  icon: const Icon(Icons.add),
                  label: const Text('New Subject'),
                )
              ],
            ),
          ),
          if (appState.subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Create subjects first to assign them to slots.',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.selectedDays.map((day) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: widget.dailySlots.length,
                  itemBuilder: (context, index) {
                    final slot = widget.dailySlots[index];
                    final timeString =
                        '${slot.startTime.format(context)} - ${slot.endTime.format(context)}';

                    if (slot.isBreak) {
                      return Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          leading: const Icon(Icons.coffee),
                          title: const Text('Break'),
                          subtitle: Text(timeString),
                        ),
                      );
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(timeString)),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int?>(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                hint: const Text('Select Subject'),
                                value: _assignedSubjects[day]![index],
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('None'),
                                  ),
                                  ...appState.subjects
                                      .map((sub) => DropdownMenuItem(
                                            value: sub.id,
                                            child: Text(sub.name),
                                          )),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _assignedSubjects[day]![index] = val;
                                  });
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _finishSetup,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Finish Setup', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
