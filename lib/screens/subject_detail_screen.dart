import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/attendance_record.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';

/// Detail drilldown for a single subject on the stats page.
class SubjectDetailScreen extends StatelessWidget {
  final Subject subject;
  final Map<String, dynamic> stats;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final subTotal = stats['total']!;
    final subAttended = stats['attended']!;
    final pct = subTotal == 0 ? 0.0 : (subAttended / subTotal) * 100;
    final color = subject.colorHex != null
        ? Color(int.parse(subject.colorHex!.replaceFirst('#', '0xFF')))
        : Colors.blueGrey;

    // Collect recent records for this subject (most recent first)

    final List<AttendanceRecord> recentRecords = [];
    if (appState.currentSession != null) {
      final startDate = appState.currentSession!.startDate;
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      DateTime cursor = todayOnly;

      int safetyCounter = 0;
      while (!cursor.isBefore(startDate) && recentRecords.length < 10 && safetyCounter < 300) {
        safetyCounter++;
        final dayOfWeek = cursor.weekday;
        
        final dateStr = cursor.toIso8601String().split('T')[0];
        final isHoliday = appState.attendanceRecords.any((r) => 
            r.status == AttendanceStatus.holiday && 
            r.date.toIso8601String().split('T')[0] == dateStr);

        if (!isHoliday) {
          for (var entry in appState.timetableEntries) {
            if (entry.subjectId == subject.id && !entry.isBreak && entry.dayOfWeek == dayOfWeek) {
              final status = appState.getDisplayStatus(entry, cursor);
              if (status != AttendanceStatus.empty &&
                  status != AttendanceStatus.holiday &&
                  status != AttendanceStatus.cancelled) {
                recentRecords.add(AttendanceRecord(
                  sessionId: appState.currentSession!.id!,
                  date: cursor,
                  timetableEntryId: entry.id,
                  status: status,
                ));
              }
            }
          }
        }
        cursor = cursor.subtract(const Duration(days: 1));
      }
      recentRecords.sort((a, b) => b.date.compareTo(a.date));
    }

    final statsMap = stats['modifiers'] as Map<int, Map<String, int>>? ?? {};
    final activeModifiers = statsMap.entries.where((e) => e.value['total']! > 0 && e.key != -1).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.name),
            if (subject.subjectCode?.isNotEmpty == true ||
                subject.professor?.isNotEmpty == true)
              Text(
                [
                  if (subject.subjectCode?.isNotEmpty == true)
                    subject.subjectCode!,
                  if (subject.professor?.isNotEmpty == true) subject.professor!,
                ].join(' • '),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: color.withOpacity(0.15),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall percentage card
          Card(
            elevation: 0,
            color: color.withOpacity(0.15),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Overall Attendance',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '$subAttended / $subTotal classes',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 72,
                    width: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: subTotal == 0 ? 0 : subAttended / subTotal,
                          strokeWidth: 7,
                          color: color,
                          backgroundColor: color.withOpacity(0.2),
                        ),
                        Center(
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _colorForPct(
                                    pct, appState.minAttendancePercentage)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Modifiers breakdown
          if (activeModifiers.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: activeModifiers.map((e) {
                final modId = e.key;
                final modName = modId == -1 
                    ? 'None' 
                    : appState.modifiers.where((m) => m.id == modId).firstOrNull?.name ?? 'Unknown';
                final modColorHex = modId != -1 
                    ? appState.modifiers.where((m) => m.id == modId).firstOrNull?.colorHex 
                    : null;
                final modColor = modColorHex != null
                    ? Color(int.parse(modColorHex.replaceFirst('#', '0xFF')))
                    : Colors.blueGrey;

                return SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 22,
                  child: _statCard(context, modName, e.value['attended']!,
                      e.value['total']!, modColor, appState.minAttendancePercentage),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Recent lectures passbook
          Text('Recent Lectures',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),

          if (recentRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: Text('No lecture records yet for this subject.')),
            )
          else
            ...recentRecords.map((record) {
              final entry = appState.timetableEntries
                  .where((e) => e.id == record.timetableEntryId)
                  .firstOrNull;
              return _passbookTile(context, record, entry);
            }),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, int attended, int total,
      Color color, double threshold) {
    final pct = total == 0 ? 0.0 : (attended / total) * 100;
    final alertColor = color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: alertColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: alertColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$attended / $total',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? 0 : attended / total,
              color: alertColor,
              backgroundColor: alertColor.withOpacity(0.2),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('${pct.toStringAsFixed(1)}%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: alertColor)),
          ],
        ),
      ),
    );
  }

  Color _colorForPct(double pct, double threshold) {
    if (pct >= threshold) return Colors.green;
    return Colors.red;
  }

  Widget _passbookTile(
      BuildContext context, AttendanceRecord record, TimetableEntry? entry) {
    final isAttended = record.status == AttendanceStatus.attended;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(record.date);
    final timeLabel = entry != null
        ? '${entry.startTime.format(context)} – ${entry.endTime.format(context)}'
        : '';
    final typeLabel = entry != null
        ? (entry.modifierId != null && entry.modifierId != 1 ? '(L)' : '')
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Icon(
            isAttended ? Icons.check_circle : Icons.cancel,
            color: isAttended ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (timeLabel.isNotEmpty)
                  Text('$timeLabel  $typeLabel',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            isAttended ? 'Attended' : 'Missed',
            style: TextStyle(
              color: isAttended ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overall attendance detail screen.
class OverallDetailScreen extends StatelessWidget {
  final int totalClasses, totalAttended;
  final Map<int, Map<String, int>> globalModifierStats;

  const OverallDetailScreen({
    super.key,
    required this.totalClasses,
    required this.totalAttended,
    required this.globalModifierStats,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pct = totalClasses == 0 ? 0.0 : (totalAttended / totalClasses) * 100;
    final color = _colorForPct(pct, appState.minAttendancePercentage);

    // Recent 3 days that had lectures
    final today = DateTime.now();
    final recent3Days = _getRecentDays(appState, today, 3);

    return Scaffold(
      appBar: AppBar(title: const Text('Overall Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall circle
          Card(
            elevation: 0,
            color: color.withOpacity(0.15),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Subjects Combined',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('$totalAttended / $totalClasses classes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: totalClasses == 0
                              ? 0
                              : totalAttended / totalClasses,
                          strokeWidth: 8,
                          color: color,
                          backgroundColor: color.withOpacity(0.2),
                        ),
                        Center(
                          child: Text('${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (globalModifierStats.entries.any((e) => e.value['total']! > 0 && e.key != -1))
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: globalModifierStats.entries
                  .where((e) => e.value['total']! > 0 && e.key != -1)
                  .map((e) {
                final modId = e.key;
                final modName = modId == -1 
                    ? 'None' 
                    : appState.modifiers.where((m) => m.id == modId).firstOrNull?.name ?? 'Unknown';
                final modColorHex = modId != -1 
                    ? appState.modifiers.where((m) => m.id == modId).firstOrNull?.colorHex 
                    : null;
                final modColor = modColorHex != null
                    ? Color(int.parse(modColorHex.replaceFirst('#', '0xFF')))
                    : Colors.blueGrey;

                return SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 22,
                  child: _statCard(context, modName, e.value['attended']!,
                      e.value['total']!, modColor, appState.minAttendancePercentage),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          Text('Recent Days',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (recent3Days.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No recent lecture data available.')),
            )
          else
            ...recent3Days
                .map((dayData) => _daySection(context, dayData, appState)),
        ],
      ),
    );
  }

  Color _colorForPct(double pct, double threshold) {
    if (pct >= threshold) return Colors.green;
    return Colors.red;
  }

  Widget _statCard(BuildContext context, String label, int attended, int total,
      Color color, double threshold) {
    final pct = total == 0 ? 0.0 : (attended / total) * 100;
    final alertColor = color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: alertColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: alertColor)),
            ]),
            const SizedBox(height: 8),
            Text('$attended / $total',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? 0 : attended / total,
              color: alertColor,
              backgroundColor: alertColor.withOpacity(0.2),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('${pct.toStringAsFixed(1)}%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: alertColor)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRecentDays(
      AppState appState, DateTime today, int dayCount) {
    if (appState.currentSession == null) return [];
    
    final startDate = appState.currentSession!.startDate;
    final results = <Map<String, dynamic>>[];
    var cursor = DateTime(today.year, today.month, today.day);

    while (results.length < dayCount && !cursor.isBefore(startDate) && !cursor.isBefore(today.subtract(const Duration(days: 90)))) {
      final dateStr = cursor.toIso8601String().split('T')[0];
      
      final isHoliday = appState.attendanceRecords.any((r) => 
          r.status == AttendanceStatus.holiday && 
          r.date.toIso8601String().split('T')[0] == dateStr);

      if (!isHoliday) {
        final recordsThisDay = <AttendanceRecord>[];
        final dayOfWeek = cursor.weekday;
        
        for (var entry in appState.timetableEntries) {
          if (!entry.isBreak && entry.subjectId != null) {
            if (entry.dayOfWeek == dayOfWeek) {
              final status = appState.getDisplayStatus(entry, cursor);
              if (status != AttendanceStatus.empty &&
                  status != AttendanceStatus.holiday &&
                  status != AttendanceStatus.cancelled) {
                recordsThisDay.add(AttendanceRecord(
                  sessionId: appState.currentSession!.id!,
                  date: cursor,
                  timetableEntryId: entry.id,
                  status: status,
                ));
              }
            }
          }
        }
        
        if (recordsThisDay.isNotEmpty) {
          // Sort records on this day by start time
          recordsThisDay.sort((a, b) {
            final entryA = appState.timetableEntries.firstWhere((e) => e.id == a.timetableEntryId);
            final entryB = appState.timetableEntries.firstWhere((e) => e.id == b.timetableEntryId);
            return (entryA.startTime.hour * 60 + entryA.startTime.minute)
                .compareTo(entryB.startTime.hour * 60 + entryB.startTime.minute);
          });
          results.add({'date': cursor, 'records': recordsThisDay});
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return results;
  }

  Widget _daySection(
      BuildContext context, Map<String, dynamic> dayData, AppState appState) {
    final date = dayData['date'] as DateTime;
    final records = dayData['records'] as List<AttendanceRecord>;
    final dateLabel = DateFormat('EEEE, MMM d').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(dateLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  )),
        ),
        ...records.map((record) {
          final entry = appState.timetableEntries
              .where((e) => e.id == record.timetableEntryId)
              .firstOrNull;
          final subject = entry?.subjectId != null
              ? appState.subjects
                  .where((s) => s.id == entry!.subjectId)
                  .firstOrNull
              : null;
          final isAttended = record.status == AttendanceStatus.attended;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Icon(
                  isAttended ? Icons.check_circle : Icons.cancel,
                  color: isAttended ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject?.name ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (entry != null)
                        Text(
                          entry.startTime.format(context),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Text(
                  isAttended ? 'Attended' : 'Missed',
                  style: TextStyle(
                    color: isAttended ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
