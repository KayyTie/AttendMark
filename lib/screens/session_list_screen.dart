import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/app_state.dart';
import '../repositories/session_repository.dart';
import 'onboarding/welcome_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final SessionRepository _sessionRepo = SessionRepository();
  bool _isLoading = true;
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _sessionRepo.getAllSessions();

    // Active sessions first, then descending by start date
    sessions.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.startDate.compareTo(a.startDate);
    });

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Sessions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sessions found.'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final session = _sessions[i];
                    final isViewing =
                        session.id == appState.currentSession?.id;
                    final dateFormat = DateFormat('MMM d, yyyy');
                    final dateString =
                        '${dateFormat.format(session.startDate)} — ${session.endDate != null && !session.isActive ? dateFormat.format(session.endDate!) : "Present"}';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      leading: CircleAvatar(
                        backgroundColor: session.isActive
                            ? Colors.green
                            : Colors.grey.shade400,
                        child: Icon(
                          session.isActive
                              ? Icons.school
                              : Icons.inventory_2,
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            session.name,
                            style: TextStyle(
                              fontWeight: isViewing
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isViewing) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Viewing',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          if (!session.isActive) ...[
                            const SizedBox(width: 6),
                            const Text(' [ended]',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ],
                      ),
                      subtitle: Text(dateString),
                      selected: isViewing,
                      onTap: () async {
                        if (!isViewing) {
                          await appState.switchSession(session);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Session?'),
                              content: const Text(
                                  'Are you sure you want to delete this session? All associated subjects, timetable slots, and attendance data will be permanently lost.'),
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
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            if (!context.mounted) return;
                            await context
                                .read<AppState>()
                                .deleteSession(session.id!);
                            if (mounted) {
                              _loadSessions();
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
      // Always-visible FAB — multiple sessions can coexist
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Start New Session'),
      ),
    );
  }
}

