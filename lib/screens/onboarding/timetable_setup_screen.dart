import 'package:flutter/material.dart';
import 'daily_subject_screen.dart';

class TimetableSetupScreen extends StatefulWidget {
  const TimetableSetupScreen({super.key});

  @override
  State<TimetableSetupScreen> createState() => _TimetableSetupScreenState();
}

class _TimetableSetupScreenState extends State<TimetableSetupScreen> {
  final List<int> _selectedDays = [1, 2, 3, 4, 5]; // Default Mon-Fri

  // A temporary class to hold the structure of a day's schedule
  final List<_TimeSlot> _dailySlots = [];

  @override
  void initState() {
    super.initState();
    // Default 5 lectures
    for (int i = 0; i < 5; i++) {
      _dailySlots.add(_TimeSlot(
        startTime: TimeOfDay(hour: 9 + i, minute: 0),
        endTime: TimeOfDay(hour: 10 + i, minute: 0),
        isBreak: false,
      ));
    }
  }

  void _addSlot() {
    setState(() {
      TimeOfDay lastEnd = _dailySlots.isNotEmpty
          ? _dailySlots.last.endTime
          : const TimeOfDay(hour: 9, minute: 0);

      _dailySlots.add(_TimeSlot(
        startTime: lastEnd,
        endTime: TimeOfDay(hour: lastEnd.hour + 1, minute: lastEnd.minute),
        isBreak: false,
      ));
    });
  }

  Future<void> _selectTime(int index, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          isStart ? _dailySlots[index].startTime : _dailySlots[index].endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _dailySlots[index].startTime = picked;
        } else {
          _dailySlots[index].endTime = picked;
        }
      });
    }
  }

  Future<void> _saveAndContinue() async {
    // NOTE: This basic setup assumes the daily structure is the same for every working day.
    // The user can customize subjects later, but the slots will be instantiated.
    // To implement creating entries, I need direct DB access or add a method to AppState.

    // For now we will pass this structure to the next screen to assign subjects
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DailySubjectScreen(
          selectedDays: _selectedDays,
          dailySlots: _dailySlots,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Structure'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Select Working Days',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1;
                final dayNames = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun'
                ];
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(dayNames[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('2. Daily Schedule',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Slot'),
                )
              ],
            ),
            const Text('Set the timings for lectures and breaks.'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _dailySlots.length,
                itemBuilder: (context, index) {
                  final slot = _dailySlots[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Column(
                            children: [
                              const Text('Break?'),
                              Switch(
                                value: slot.isBreak,
                                onChanged: (val) {
                                  setState(() {
                                    slot.isBreak = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _selectTime(index, true),
                                        child: Text(
                                            slot.startTime.format(context)),
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('to'),
                                    ),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _selectTime(index, false),
                                        child:
                                            Text(slot.endTime.format(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _dailySlots.removeAt(index);
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedDays.isEmpty || _dailySlots.isEmpty
                    ? null
                    : _saveAndContinue,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Next: Assign Subjects',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  bool isBreak;

  _TimeSlot(
      {required this.startTime, required this.endTime, required this.isBreak});
}
