import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session.dart';
import '../repositories/session_repository.dart';
import '../database/database_helper.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final _sessionRepo = SessionRepository();
  List<Session> _sessions = [];
  final Set<int> _selectedIds = {};
  final TextEditingController _filenameCtrl = TextEditingController(text: 'backup');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _sessionRepo.getAllSessions();
    setState(() {
      _sessions = sessions;
      _selectedIds.addAll(sessions.map((s) => s.id!)); // select all by default
      _isLoading = false;
    });
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }

      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;

      final status2 = await Permission.storage.request();
      if (status2.isGranted) return true;

      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
              'Please grant storage access / "All files access" in settings so the app can save your backup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return false;
    }
    return true; 
  }

  Future<void> _export() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one session.')));
      return;
    }
    if (_filenameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a filename.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasPerm = await _requestStoragePermission();
      if (!hasPerm) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> exportedSessions = [];

      for (var id in _selectedIds) {
        final sessionResult = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
        if (sessionResult.isEmpty) continue;
        final sessionMap = Map<String, dynamic>.from(sessionResult.first);

        final subjects = await db.query('subjects', where: 'session_id = ?', whereArgs: [id]);
        sessionMap['subjects'] = subjects;

        final timetable = await db.query('timetable_entries', where: 'session_id = ?', whereArgs: [id]);
        sessionMap['timetable'] = timetable;

        final attendance = await db.query('attendance_records', where: 'session_id = ?', whereArgs: [id]);
        sessionMap['attendance'] = attendance;

        exportedSessions.add(sessionMap);
      }

      final payload = {
        'version': 1,
        'appName': 'AttendMark',
        'exportedAt': DateTime.now().toIso8601String(),
        'sessions': exportedSessions,
      };

      final jsonStr = jsonEncode(payload);
      final fileName = '${_filenameCtrl.text.trim()}.json';
      File? savedFile;

      try {
        final dir = Directory('/storage/emulated/0/AttendMark');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(jsonStr);
        savedFile = file;
      } catch (e) {
        final fallbackDir = Directory('/storage/emulated/0/Download/AttendMark');
        if (!await fallbackDir.exists()) await fallbackDir.create(recursive: true);
        final file = File('${fallbackDir.path}/$fileName');
        await file.writeAsString(jsonStr);
        savedFile = file;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported successfully to ${savedFile.path}')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      // If permission_handler threw MissingPluginException, they didn't do a full stop & rebuild.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Failed'),
          content: Text(
              'An error occurred. If you recently added permissions, make sure you clicked the Red Stop button and then the Green Play button in Android Studio to fully rebuild the app, NOT just Hot Restart/Reload.\n\nError: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _filenameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filename',
                      suffixText: '.json',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select Sessions to Export',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      final isSelected = _selectedIds.contains(s.id);
                      return CheckboxListTile(
                        title: Text(s.name),
                        subtitle: Text(
                            '${s.startDate.toLocal().toString().split(' ')[0]} - ${s.endDate?.toLocal().toString().split(' ')[0] ?? 'Ongoing'}'),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(s.id!);
                            } else {
                              _selectedIds.remove(s.id!);
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
                      onPressed: _selectedIds.isEmpty ? null : _export,
                      child: const Text('Export Selected'),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
