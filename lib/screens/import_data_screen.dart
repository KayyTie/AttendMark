import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../database/database_helper.dart';

class ImportDataScreen extends StatefulWidget {
  final String filePath;
  const ImportDataScreen({super.key, required this.filePath});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  bool _isLoading = true;
  List<dynamic> _parsedSessions = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _parseFile();
  }

  Future<void> _parseFile() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data['sessions'] != null && data['sessions'] is List) {
        setState(() {
          _parsedSessions = data['sessions'];
          // By default, select all
          for (int i = 0; i < _parsedSessions.length; i++) {
            _selectedIndices.add(i);
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid JSON format: no sessions array.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing file: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _import() async {
    if (_selectedIndices.isEmpty) return;

    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    try {
      for (final index in _selectedIndices) {
        final sessionData = _parsedSessions[index] as Map<String, dynamic>;

        // 1. Insert Session
        final Map<String, dynamic> sessionMap = {
          'name': '${sessionData['name']} (Imported)',
          'start_date': sessionData['start_date'],
          'end_date': sessionData['end_date'],
          'is_active': sessionData['is_active'] ?? 1,
        };
        final newSessionId = await db.insert('sessions', sessionMap);

        // 2. Insert Subjects and Map IDs
        final Map<int, int> subjectIdMap = {};
        final subjects = sessionData['subjects'] as List<dynamic>? ?? [];
        for (final sub in subjects) {
          final oldSubId = sub['id'] as int;
          final Map<String, dynamic> newSubData = Map<String, dynamic>.from(sub);
          newSubData.remove('id');
          newSubData['session_id'] = newSessionId;
          final newSubId = await db.insert('subjects', newSubData);
          subjectIdMap[oldSubId] = newSubId;
        }

        // 3. Insert Timetable Entries and Map IDs
        final Map<int, int> timetableIdMap = {};
        final timetables = sessionData['timetable'] as List<dynamic>? ?? [];
        for (final entry in timetables) {
          final oldEntryId = entry['id'] as int;
          final Map<String, dynamic> newEntryData = Map<String, dynamic>.from(entry);
          newEntryData.remove('id');
          newEntryData['session_id'] = newSessionId;

          if (newEntryData['subject_id'] != null) {
            newEntryData['subject_id'] = subjectIdMap[newEntryData['subject_id'] as int];
          }

          if (!newEntryData.containsKey('is_lab')) {
            newEntryData['is_lab'] = 0;
          }

          final newEntryId = await db.insert('timetable_entries', newEntryData);
          timetableIdMap[oldEntryId] = newEntryId;
        }

        // 4. Insert Attendance Records
        final attendance = sessionData['attendance'] as List<dynamic>? ?? [];
        for (final record in attendance) {
          final Map<String, dynamic> newRecordData = Map<String, dynamic>.from(record);
          newRecordData.remove('id');
          newRecordData['session_id'] = newSessionId;

          if (newRecordData['timetable_entry_id'] != null) {
            newRecordData['timetable_entry_id'] =
                timetableIdMap[newRecordData['timetable_entry_id'] as int];
          }
          await db.insert('attendance_records', newRecordData);
        }
      }

      if (!mounted) return;
      await context.read<AppState>().init();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessions imported successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error importing: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parsedSessions.isEmpty
              ? const Center(child: Text('No sessions discovered in file.'))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Select sessions to import into your database:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _parsedSessions.length,
                        itemBuilder: (context, index) {
                          final s = _parsedSessions[index] as Map<String, dynamic>;
                          final name = s['name'] ?? 'Unnamed Session';
                          final startDate = s['start_date']?.split('T')[0] ?? '';
                          final isSelected = _selectedIndices.contains(index);

                          return CheckboxListTile(
                            title: Text(name),
                            subtitle: Text('Start Date: $startDate'),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _selectedIndices.isEmpty ? null : _import,
                          child: Text('Import ${_selectedIndices.length} Session(s)'),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}
