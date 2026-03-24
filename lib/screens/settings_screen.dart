import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';


import '../models/session.dart';
import '../repositories/session_repository.dart';
import 'session_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sessionRepo = SessionRepository();

  @override
  void initState() {
    super.initState();
  }





  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
            'This will archive your current session. You will need to start a new one to continue tracking.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final appState = context.read<AppState>();
      if (appState.currentSession != null) {
        final endedSession = Session(
          id: appState.currentSession!.id,
          name: appState.currentSession!.name,
          startDate: appState.currentSession!.startDate,
          endDate: DateTime.now(),
          isActive: false,
        );
        await _sessionRepo.update(endedSession);
        await appState.init(); // Refresh global app state to get active session
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SessionListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme across the application'),
            value: appState.themeMode == ThemeMode.dark,
            onChanged: (val) {
              appState.updateTheme(val ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minimum Attendance Target', 
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Required percentage to stay on track',
                        style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: appState.minAttendancePercentage.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed >= 0 && parsed <= 100) {
                        context.read<AppState>().updateMinAttendance(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          if (appState.currentSession?.isActive == true)
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('End Current Session',
                  style: TextStyle(color: Colors.orange)),
              subtitle: Text(
                  'Archiving ${appState.currentSession?.name ?? 'current'} session'),
              onTap: _endSession,
            ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('AttendMark v1.1.0', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
